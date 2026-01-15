module Api
  module User
    # Service to determine the status of commodity codes submitted by the user
    #
    # Active - An active code is one that is current for today's date and is declarable (i.e., has no children)
    # Expired - An expired code is a declarable code that is not active today, or has had children added later
    # Invalid - The code never existed or was never declarable
    class ActiveCommoditiesService
      attr_reader :uploaded_commodity_codes, :subscription_target_ids

      def self.refresh_caches
        Rails.cache.delete('myott_all_active_commodities')
        all_active_commodities
        Rails.cache.delete('myott_all_expired_commodities')
        all_expired_commodities
      end

      def self.all_active_commodities
        @all_active_commodities ||= Rails.cache.fetch('myott_all_active_commodities', expires_at: 2.days.from_now) do
          TimeMachine.now { GoodsNomenclature.actual.declarable.pluck(:goods_nomenclature_sid, :goods_nomenclature_item_id) }
        end
      end

      # Optimized to accept target_sids to limit the scope of the query when caching is disabled (e.g. in tests/development)
      def self.all_expired_commodities(target_sids: nil)
        cache_key = target_sids ? "myott_expired_commodities_#{target_sids.hash}" : 'myott_all_expired_commodities'

        @all_expired_commodities ||= Rails.cache.fetch(cache_key, expires_at: 2.days.from_now) do
          expired_candidates = TimeMachine.no_time_machine do
            query = GoodsNomenclature
              .where(producline_suffix: GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX)

            query = query.where(goods_nomenclature_sid: target_sids) if target_sids

            query.pluck(:goods_nomenclature_sid, :goods_nomenclature_item_id)
              .reject { |sid, _| all_active_commodities.any? { |active_sid, _| active_sid == sid } }
          end

          return [] if expired_candidates.empty?

          expired_sids = expired_candidates.map(&:first)

          # Find commodities that have children within a day of the same validity_start_date
          commodities_with_same_date_children = TimeMachine.now do
            GoodsNomenclature
              .where(goods_nomenclatures__goods_nomenclature_sid: expired_sids)
              .eager(:children)
              .all
              .select { |commodity|
                commodity.children.any? do |child|
                  child.validity_start_date && commodity.validity_start_date &&
                    child.validity_start_date <= commodity.validity_start_date + 1.day
                end
              }
              .map(&:goods_nomenclature_sid)
              .to_set
          end

          expired_candidates
            .reject { |sid, _| commodities_with_same_date_children.include?(sid) }
            .map { |sid, code| [sid, code] }
        end
      end

      def initialize(subscription)
        @uploaded_commodity_codes = subscription.get_metadata_key('commodity_codes')
        @subscription_target_ids = subscription.subscription_targets_dataset.commodities.map(&:target_id)
      end

      def call
        return {} if uploaded_commodity_codes.blank?

        {
          active: active_commodity_codes.count,
          expired: expired_commodity_codes.count,
          invalid: invalid_commodity_codes.count,
        }
      end

      # --- Public paginated loaders ---
      # Each returns [array_of_commodities, total_count]

      def active_commodities(page: nil, per_page: nil)
        codes = active_commodity_codes.to_a.sort
        total = codes.size
        paginated_codes = paginate_codes(codes, page, per_page)

        records = load_goods_nomenclatures_by_codes(paginated_codes)

        [records, total]
      end

      def expired_commodities(page: nil, per_page: nil)
        codes = expired_commodity_codes.to_a.sort
        total = codes.size
        paginated_codes = paginate_codes(codes, page, per_page)

        records = load_goods_nomenclatures_by_codes(paginated_codes)
        records = records.map { |commodity| apply_validity_end_date(commodity) }

        [records, total]
      end

      def invalid_commodities(page: nil, per_page: nil)
        codes = invalid_commodity_codes.to_a.sort
        total = codes.size
        paginated_codes = paginate_codes(codes, page, per_page)

        [materialize_with_nulls(paginated_codes), total]
      end

      private

      # --- Core data loaders ---

      def load_goods_nomenclatures_by_codes(codes)
        return [] if codes.empty?

        GoodsNomenclature
          .where(goods_nomenclatures__goods_nomenclature_item_id: codes)
          .eager(:goods_nomenclature_descriptions)
          .all
          .index_by(&:goods_nomenclature_item_id).values
      end

      # Returns a mix of GoodsNomenclature (if exists) or NullCommodity (if missing)
      def materialize_with_nulls(codes)
        return [] if codes.empty?

        records = load_goods_nomenclatures_by_codes(codes)
        records_by_id = records.index_by(&:goods_nomenclature_item_id)

        # Use ordered results to match input codes order
        codes.map do |code|
          records_by_id[code] || PublicUsers::NullCommodity.new(goods_nomenclature_item_id: code)
        end
      end

      def paginate_codes(codes, page, per_page)
        return codes unless page && per_page

        offset = (page - 1) * per_page
        codes.slice(offset, per_page) || []
      end

      # --- data loaders for an individual subscription ---

      def active_commodity_codes
        @active_commodity_codes ||= begin
          sid_to_code = self.class.all_active_commodities.to_h { |sid, code| [sid, code] }
          codes = subscription_target_ids.map { |sid| sid_to_code[sid] }.compact

          Set.new(codes)
        end
      end

      def expired_commodity_codes
        @expired_commodity_codes ||= begin
          sid_to_code = if Rails.application.config.action_controller.perform_caching
                          self.class.all_expired_commodities.to_h { |sid, code| [sid, code] }
                        else
                          self.class.all_expired_commodities(target_sids: subscription_target_ids).to_h { |sid, code| [sid, code] }
                        end

          codes = subscription_target_ids.map { |sid| sid_to_code[sid] }.compact

          Set.new(codes) - active_commodity_codes
        end
      end

      def invalid_commodity_codes
        @invalid_commodity_codes ||=
          Set.new(uploaded_commodity_codes) - active_commodity_codes - expired_commodity_codes
      end

      # --- Validity end date enrichment ---

      def apply_validity_end_date(commodity)
        return commodity if commodity.values[:validity_end_date].present?

        end_date = calculate_end_date_from_descendants(commodity)
        commodity.values[:validity_end_date] = end_date if end_date

        commodity
      end

      def calculate_end_date_from_descendants(commodity)
        earliest_child_start = commodity.children.minimum(:validity_start_date)
        return nil if earliest_child_start.blank?

        earliest_child_start.to_date - 1
      end
    end
  end
end
