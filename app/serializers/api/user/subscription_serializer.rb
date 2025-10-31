module Api
  module User
    class SubscriptionSerializer
      include JSONAPI::Serializer

      set_type :subscription

      set_id :uuid

      attributes :active, :metadata

      attribute :subscription_type do |subscription|
        subscription.subscription_type.name
      end

      attribute :meta do |_subscription, params|
        params && params[:meta]
      end

      has_one :subscription_type, serializer: Api::User::SubscriptionTypeSerializer
    end
  end
end
