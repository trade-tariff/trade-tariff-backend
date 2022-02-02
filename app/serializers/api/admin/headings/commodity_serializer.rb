module Api
  module Admin
    module Headings
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :admin_id

        attributes :description

        attribute :declarable, &:declarable?

        attribute :search_references_count do |commodity|
          if commodity.declarable?
            commodity.search_references.count
          else
            Subheading.find(goods_nomenclature_sid: commodity.goods_nomenclature_sid).search_references.count
          end
        end
      end
    end
  end
end
