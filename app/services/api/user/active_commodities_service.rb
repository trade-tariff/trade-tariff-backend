module Api
  module User
    # Service to determine the status of commodity codes submitted by the user
    #
    # Active - An active code is one that is current for today's date and is declarable (i.e., has no children)
    # Expired - An expired code is a declarable code that is not active today, or had descendants that are now expired
    # Invalid - The code never existed or was never declarable (always a grouping/subheading)
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

      # --- Public paginated loaders ---
      # Each returns [array_of_commodities, total_count]

      def active_commodities(page: nil, per_page: nil)
        codes = active_commodity_codes.sort.uniq
        total = codes.size
        paginated_codes = paginate_codes(codes, page, per_page)

        [load_goods_nomenclatures_by_codes(paginated_codes), total]
      end

      def expired_commodities(page: nil, per_page: nil)
        codes = expired_commodity_codes
        total = codes.size
        paginated_codes = paginate_codes(codes, page, per_page)

        records = load_goods_nomenclatures_by_codes(paginated_codes)
        records = records.map { |commodity| apply_validity_end_date(commodity) }

        [records, total]
      end

      def invalid_commodities(page: nil, per_page: nil)
        codes = invalid_commodity_codes.sort.uniq
        total = codes.size
        paginated_codes = paginate_codes(codes, page, per_page)

        [materialize_with_nulls(paginated_codes), total]
      end

      private

      # --- Core data loaders ---

      def load_goods_nomenclatures_by_codes(codes)
        return [] if codes.empty?

        GoodsNomenclature
          .where(goods_nomenclature_item_id: codes)
          .all
          .uniq(&:goods_nomenclature_item_id)
      end

      # Returns a mix of GoodsNomenclature (if exists) or NullCommodity (if missing)
      def materialize_with_nulls(codes)
        return [] if codes.empty?

        records = load_goods_nomenclatures_by_codes(codes)
        records_by_id = records.index_by(&:goods_nomenclature_item_id)

        codes.map do |code|
          records_by_id[code] || PublicUsers::NullCommodity.new(goods_nomenclature_item_id: code)
        end
      end

      # --- Pagination helper ---

      def paginate_codes(codes, page, per_page)
        return codes unless page && per_page

        offset = (page - 1) * per_page
        codes.slice(offset, per_page) || []
      end

      # --- Code classification logic ---

      def active_commodity_codes
        @active_commodity_codes ||= active_candidates
          .select(&:declarable?)
          .map(&:goods_nomenclature_item_id)
      end

      def expired_commodity_codes
        @expired_commodity_codes ||= (historically_declarable_commodity_codes - active_commodity_codes).uniq
      end

      def invalid_commodity_codes
        @invalid_commodity_codes ||= begin
          never_existed = uploaded_commodity_codes - historical_commodity_codes
          historical_non_declarable = historical_commodity_codes - historically_declarable_commodity_codes

          (never_existed + historical_non_declarable).uniq
        end
      end

      def historically_declarable_commodity_codes
        @historically_declarable_commodity_codes ||= begin
          operations = GoodsNomenclature::Operation
            .where(goods_nomenclature_sid: subscription_target_ids)
            .all

          ever_declarables(operations)
        end
      end

      def ever_declarables(operations)
        item_ids = operations.map(&:goods_nomenclature_item_id).uniq

        all_candidates = GoodsNomenclature
          .where(goods_nomenclatures__goods_nomenclature_item_id: item_ids)
          .all

        item_ids.select { |item_id|
          versions = all_candidates.select { |gn| gn.goods_nomenclature_item_id == item_id }
          versions.any? do |version|
            next false if version.instance_of?(Chapter) ||
              (version.instance_of?(Heading) && !version.declarable?) ||
              (version.instance_of?(Subheading) && !version.declarable?)

            true
          end
        }.uniq
      end

      def historical_commodity_codes
        @historical_commodity_codes ||= GoodsNomenclature::Operation
          .where(goods_nomenclature_sid: subscription_target_ids)
          .pluck(:goods_nomenclature_item_id)
      end

      # --- Data fetchers ---

      def active_candidates
        @active_candidates ||= ::GoodsNomenclature
          .actual
          .with_leaf_column
          .where(goods_nomenclatures__goods_nomenclature_sid: subscription_target_ids)
          .all
          .select(&:leaf?)
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

        earliest_child_start.to_date
      end
    end
  end
end
