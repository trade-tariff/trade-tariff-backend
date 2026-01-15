module Api
  module User
    class SubscriptionSerializer
      include JSONAPI::Serializer

      set_type :subscription

      set_id :uuid

      attributes :active

      attribute :meta do |subscription|
        service_class = "Api::User::#{subscription.subscription_type.name.camelize}MetaService".safe_constantize
        if service_class
          service_class.new(subscription).call
        end
      end

      has_one :subscription_type, serializer: Api::User::SubscriptionTypeSerializer
    end
  end
end
