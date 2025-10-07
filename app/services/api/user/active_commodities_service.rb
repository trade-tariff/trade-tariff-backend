module Api
  module User
    # Service to determine the status of commodity codes submitted by the user
    #
    # Active - An active code is one that is current for today's date and is declarable (i.e., has no children). End date is in the future or null and start date is in the past
    # Moved - A moved code is one that is active but not declarable (i.e., now has children) and also has no ancestors that share the same code and are still active
    # Expired - An expired code is a declarable code that is not active today
    # Invalid - the code never existed
    # Erroneous - either the code never existed or the code existed and has moved
    class ActiveCommoditiesService
      def initialize(original_codes)
        @original_codes = original_codes
      end

      def call
        all_codes = ::GoodsNomenclature
          .actual
          .with_leaf_column
          .where(goods_nomenclatures__goods_nomenclature_item_id: original_codes)
          .all

        full_history = GoodsNomenclature::Operation.where(goods_nomenclature_item_id: original_codes).pluck(:goods_nomenclature_item_id)

        erroneous_codes = original_codes - full_history

        active_codes = all_codes.select(&:declarable?)
                                .pluck(:goods_nomenclature_item_id)

        moved_codes = all_codes.select { |goods_nomenclature|
          !goods_nomenclature.declarable? && !goods_nomenclature.in?(active_codes)
        }
        .pluck(:goods_nomenclature_item_id)

        expired_codes = original_codes
          .reject { |code| code.in?(active_codes) }
          .reject { |code| code.in?(moved_codes) }
          .reject { |code| code.in?(erroneous_codes) }
        erroneous_codes += moved_codes
        {
          active: active_codes.sort.uniq,
          expired: expired_codes.sort.uniq,
          erroneous: erroneous_codes.sort.uniq,
        }
      end

      private

      attr_reader :original_codes
    end
  end
end
