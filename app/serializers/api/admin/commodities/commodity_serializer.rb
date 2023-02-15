module Api
  module Admin
    module Commodities
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :to_admin_param

        attributes :description, :goods_nomenclature_item_id, :producline_suffix
      end
    end
  end
end
