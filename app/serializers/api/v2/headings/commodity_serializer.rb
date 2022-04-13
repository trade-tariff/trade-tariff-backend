module Api
  module V2
    module Headings
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :goods_nomenclature_sid

        attributes :description,
                   :number_indents,
                   :goods_nomenclature_item_id,
                   :leaf,
                   :producline_suffix,
                   :goods_nomenclature_sid,
                   :formatted_description,
                   :description_plain,
                   :parent_sid

        attribute :declarable do |commodity|
          # TODO: Once we've got the ES cache populated with declarable we can use a simple attribute to pull this out
          commodity.try(:declarable) || commodity.leaf && commodity.producline_suffix == GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX
        end

        has_many :overview_measures, record_type: :measure,
                                     serializer: Api::V2::Measures::OverviewMeasureSerializer
      end
    end
  end
end
