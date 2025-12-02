module Api
  module User
    module SubscriptionTarget
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity
        set_id :id
        attributes :classification_description, :goods_nomenclature_item_id, :validity_end_date
        attribute :chapter, &:chapter_short_code
        attribute :heading, ->(commodity) { commodity.heading&.description }
      end
    end
  end
end
