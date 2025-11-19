module Api
  module User
    module SubscriptionTarget
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity
        set_id :id
        attributes :classification_description, :goods_nomenclature_item_id
      end
    end
  end
end
