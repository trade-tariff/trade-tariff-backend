module Api
  module Admin
    module Headings
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :to_admin_param

        attributes :description,
                   :search_references_count,
                   :goods_nomenclature_item_id,
                   :producline_suffix

        attribute :declarable, &:path_declarable?
      end
    end
  end
end
