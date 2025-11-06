module Api
  module User
    module SubscriptionTarget
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity
        set_id :id
        attributes :hierarchical_description
      end
    end
  end
end
