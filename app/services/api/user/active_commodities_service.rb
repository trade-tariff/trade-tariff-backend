module Api
  module User
    # Service to determine the status of commodity codes submitted by the user
    #
    # Active - An active code is one that is current for today's date and is declarable (i.e., has no children). End date is in the future or null and start date is in the past
    # Moved - A moved code is one that is active but not declarable (i.e., now has children) and also has no ancestors that share the same code and are still active
    # Expired - An expired code is a declarable code that is not active today
    # Invalid - the code never existed

    class ActiveCommoditiesService
      def initialize(subscription)
        @uploaded_commodity_codes = subscription.get_metadata_key('commodity_codes')
        @subscription_target_ids = subscription.subscription_targets_dataset.commodities.map(&:target_id)
      end

      def call
        return {} if uploaded_commodity_codes.blank?

        # load the current candidate commodities
        active_candidates = ::GoodsNomenclature
          .actual
          .with_leaf_column
          .where(goods_nomenclatures__goods_nomenclature_sid: subscription_target_ids)
          .all

        # filter out the subheadings that are also commodities
        # see 1905903000 (Bread)
        active_candidates = active_candidates.select(&:leaf?)

        active_commodity_codes = active_candidates
          .select(&:declarable?)
          .map(&:goods_nomenclature_item_id)

        moved_commodity_codes = active_candidates
          .reject(&:declarable?)
          .map(&:goods_nomenclature_item_id)

        historical_commodity_codes = GoodsNomenclature::Operation
          .where(goods_nomenclature_sid: subscription_target_ids)
          .pluck(:goods_nomenclature_item_id)

        expired_commodity_codes = historical_commodity_codes
          .reject { |code| code.in?(active_commodity_codes + moved_commodity_codes) }

        # check that expired codes are not subheadings
        # see 0406902100 (Cheese, a subheading (i.e. invalid) but was showing as expired)
        expired_candidates = ::GoodsNomenclature
          .with_leaf_column
          .where(goods_nomenclatures__goods_nomenclature_item_id: expired_commodity_codes)
          .all

        non_leaf_expired_codes = expired_candidates
          .reject(&:leaf?)
          .map(&:goods_nomenclature_item_id)

        # invalid = codes that never existed + expired codes that were actually subheadings
        invalid_commodity_codes = (
          (uploaded_commodity_codes - historical_commodity_codes) + non_leaf_expired_codes
        ).uniq

        # remove anything invalid from expired
        expired_commodity_codes -= invalid_commodity_codes

        {
          active: active_commodity_codes.sort.uniq,
          moved: moved_commodity_codes.sort.uniq,
          expired: expired_commodity_codes.sort.uniq,
          invalid: invalid_commodity_codes.sort.uniq,
        }
      end

      private

      attr_reader :uploaded_commodity_codes, :subscription_target_ids
    end
  end
end
