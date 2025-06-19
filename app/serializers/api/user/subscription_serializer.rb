module Api
  module User
    class SubscriptionSerializer
      include JSONAPI::Serializer

      set_type :subscription

      set_id :uuid

      attributes :active
    end
  end
end
