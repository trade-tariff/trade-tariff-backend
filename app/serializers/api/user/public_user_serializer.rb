module Api
  module User
    class PublicUserSerializer
      include JSONAPI::Serializer

      set_type :user

      set_id :external_id

      attributes :email, :chapter_ids, :stop_press_subscription, :my_commodities_subscription

      attribute :subscriptions do |user|
        user.subscriptions_dataset.map do |subscription|
          {
            id: subscription.uuid,
            subscription_type: subscription.subscription_type.name, # or .to_s depending on your model
            active: subscription.active,
          }
        end
      end
    end
  end
end
