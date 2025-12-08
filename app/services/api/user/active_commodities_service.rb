module Api
  module User
    # Service to determine the status of commodity codes submitted by the user
    #
    # Active - An active code is one that is current for today's date and is declarable (i.e., has no children). End date is in the future or null and start date is in the past
    # Expired - An expired code is a declarable code that is not active today, or had descendants that are now expired (ie became a subheading)
    # Invalid - the code never existed

    class ActiveCommoditiesService
      attr_reader :uploaded_commodity_codes, :subscription_target_ids

      def initialize(subscription)
        @uploaded_commodity_codes = subscription.get_metadata_key('commodity_codes')
        @subscription_target_ids = subscription.subscription_targets_dataset.commodities.map(&:target_id)
      end

      def call
        return {} if uploaded_commodity_codes.blank?

        {
          active: active_commodity_codes.sort,
          expired: expired_commodity_codes.sort,
          invalid: invalid_commodity_codes.sort,
        }
      end

      # --- Paginated loaders ---
      # Returns [array_of_commodities, total_count]

      def active_commodities(page: nil, per_page: nil)
        codes = active_commodity_codes.sort.uniq
        total = codes.size
        paginated_codes = paginate_codes(codes, page, per_page)

        # Load only commodities with producline_suffix == '80'
        paginated = Commodity
                      .where(goods_nomenclature_item_id: paginated_codes, producline_suffix: '80')
                      .all
                      .uniq(&:goods_nomenclature_item_id)

        [paginated, total]
      end

      def expired_commodities(page: nil, per_page: nil)
        codes = expired_commodity_codes
        total = codes.size
        paginated_codes = paginate_codes(codes, page, per_page)

        # Load and de-duplicate by goods_nomenclature_item_id
        paginated = Commodity
                      .where(goods_nomenclature_item_id: paginated_codes, producline_suffix: '80')
                      .all
                      .uniq(&:goods_nomenclature_item_id)

        paginated = paginated.map { |commodity| commodity_with_validity_end_date(commodity) }

        [paginated, total]
      end

      def invalid_commodities(page: nil, per_page: nil)
        existing_codes = all_candidate_codes
        missing_codes = invalid_commodity_codes - existing_codes

        existing_invalid = Commodity.where(goods_nomenclature_item_id: invalid_commodity_codes).all.uniq(&:goods_nomenclature_item_id)
        existing_invalid_ids = existing_invalid.map(&:goods_nomenclature_item_id)
        missing_codes -= existing_invalid_ids
        missing_invalid = missing_codes.uniq.map do |code|
          PublicUsers::NullCommodity.new(goods_nomenclature_item_id: code)
        end
        combined = existing_invalid + missing_invalid
        total = combined.size
        if page && per_page
          offset = (page - 1) * per_page
          combined = combined.slice(offset, per_page) || []
        end

        [combined, total]
      end

      private

      def paginate_codes(codes, page, per_page)
        return codes unless page && per_page

        offset = (page - 1) * per_page
        codes.slice(offset, per_page) || []
      end

      # --- Code-only sets ---
      def active_commodity_codes
        @active_commodity_codes ||= active_candidates.select(&:declarable?).map(&:goods_nomenclature_item_id)
      end

      def expired_commodity_codes
        # Expired should include only codes that were historically declarable
        # but are not active today. Codes that existed historically but were
        # never declarable (i.e. always grouping/subheadings) should be
        # treated as invalid instead.
        @expired_commodity_codes ||= (historically_declarable_commodity_codes - active_commodity_codes).uniq
      end

      def invalid_commodity_codes
        @invalid_commodity_codes ||= begin
          # Invalid codes are those uploaded by the user that were never seen
          # in the historical operations (never existed) PLUS historical codes
          # that were never declarable (always grouping/subheadings).
          never_existed = uploaded_commodity_codes - historical_commodity_codes
          historical_non_declarable = historical_commodity_codes - historically_declarable_commodity_codes

          (never_existed + historical_non_declarable).uniq
        end
      end

      def historically_declarable_commodity_codes
        @historically_declarable_commodity_codes ||= GoodsNomenclature::Operation
          .where(goods_nomenclature_sid: subscription_target_ids,
                 producline_suffix: GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX)
          .pluck(:goods_nomenclature_item_id)
          .uniq
      end

      def all_candidate_codes
        active_commodity_codes + expired_commodity_codes
      end

      # --- Data loaders ---
      def active_candidates
        @active_candidates ||= ::GoodsNomenclature
          .actual
          .with_leaf_column
          .where(goods_nomenclatures__goods_nomenclature_sid: subscription_target_ids)
          .all
          .select(&:leaf?)
      end

      def historical_commodity_codes
        @historical_commodity_codes ||= GoodsNomenclature::Operation
          .where(goods_nomenclature_sid: subscription_target_ids)
          .pluck(:goods_nomenclature_item_id)
      end

      def load_commodities(codes)
        Commodity.where(goods_nomenclature_item_id: codes).all
      end

      def commodity_with_validity_end_date(commodity)
        return commodity if commodity.values[:validity_end_date].present?

        end_date = get_descendants_end_date(commodity)

        commodity.values[:validity_end_date] = end_date if end_date

        commodity
      end

      def get_descendants_end_date(commodity)
        end_date = commodity.children.minimum(:validity_start_date)
        return nil if end_date.blank?

        end_date.to_date - 1
      end
    end
  end
end
