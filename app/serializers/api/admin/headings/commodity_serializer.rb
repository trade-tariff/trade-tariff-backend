module Api
  module Admin
    module Headings
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :admin_id

        attributes :description,
                   :search_references_count,
                   :goods_nomenclature_item_id,
                   :producline_suffix

        attribute :declarable, &:declarable?
      end
    end
  end
end
