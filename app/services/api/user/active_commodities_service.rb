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
        Rails.cache.write('myott_all_active_commodities', generate_fresh_active_commodities)
        Rails.cache.write('myott_all_expired_commodities', generate_fresh_expired_commodities)

        @all_active_commodities = nil
        @all_expired_commodities = nil
      end

      def self.all_active_commodities
        @all_active_commodities ||= Rails.cache.fetch('myott_all_active_commodities') do
          generate_fresh_active_commodities
        end
      end

      # Optimized to accept target_sids to limit the scope of the query when caching is disabled (e.g. in tests/development)
      def self.all_expired_commodities(target_sids: nil)
        cache_key = target_sids ? "myott_expired_commodities_#{target_sids.hash}" : 'myott_all_expired_commodities'

        @all_expired_commodities ||= Rails.cache.fetch(cache_key, expires_at: 2.days.from_now) do
          generate_fresh_expired_commodities(target_sids: target_sids)
        end
      end

      def self.generate_fresh_active_commodities
        TimeMachine.now do
          GoodsNomenclature.actual.declarable.pluck(:goods_nomenclature_sid, :goods_nomenclature_item_id)
        end
      end

      def self.generate_fresh_expired_commodities(target_sids: nil)
        expired_candidates = TimeMachine.no_time_machine do
          query = GoodsNomenclature
            .where(producline_suffix: GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX)

          query = query.where(goods_nomenclature_sid: target_sids) if target_sids

          active_sids = generate_fresh_active_commodities.map(&:first).to_set

          query.pluck(:goods_nomenclature_sid, :goods_nomenclature_item_id)
            .reject { |sid, _| active_sids.include?(sid) }
        end

        return [] if expired_candidates.empty?

        expired_sids = expired_candidates.map(&:first)

        # Find commodities that had children at their creation date
        commodities_with_creation_children = had_children_at_creation(expired_sids)

        expired_candidates
          .reject { |sid, _| commodities_with_creation_children[sid] }
          .map { |sid, code| [sid, code] }
      end

      def self.had_children_at_creation(goods_nomenclature_sids)
        return {} if goods_nomenclature_sids.empty?

        creation_data = GoodsNomenclature
          .where(goods_nomenclature_sid: goods_nomenclature_sids)
          .select(:goods_nomenclature_sid, :validity_start_date)
          .all
          .map { |gn| [gn.goods_nomenclature_sid, gn.validity_start_date] }

        results = {}

        # Group by creation date to minimize TimeMachine context switches
        creation_data.group_by(&:second).each do |creation_date, sids_and_dates|
          sids = sids_and_dates.map(&:first)

          # Allow an extra day as there are some instances where a child was created the next day
          TimeMachine.at(creation_date + 1.day) do
            leaf_data = GoodsNomenclature
              .actual
              .with_leaf_column
              .where(Sequel.qualify(:goods_nomenclatures, :goods_nomenclature_sid) => sids)
              .all

            leaf_data.each do |record|
              results[record.goods_nomenclature_sid] = !record.values[:leaf]
            end
          end
        end

        results
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
