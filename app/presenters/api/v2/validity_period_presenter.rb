module Api
  module V2
    class ValidityPeriodPresenter < SimpleDelegator
      include ContentAddressableId

      content_addressable_fields :to_param,
                                 :validity_start_date,
                                 :validity_end_date

      def deriving_goods_nomenclatures
        deriving_goods_nomenclature_origins.map(&:goods_nomenclature)
      end

      def derived_goods_nomenclature_ids
        deriving_goods_nomenclatures.map do |goods_nomenclature|
          "#{goods_nomenclature.goods_nomenclature_item_id}-#{goods_nomenclature.producline_suffix}"
        end
      end
    end
  end
end
