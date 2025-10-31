module Api
  module User
    class SubscriptionTypeSerializer
      include JSONAPI::Serializer

      set_type :subscription_type
      set_id :id

      attributes :name
    end
  end
end
