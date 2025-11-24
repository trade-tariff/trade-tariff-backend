module Api
  module User
    class PublicUserSerializer
      include JSONAPI::Serializer

      set_type :user

      set_id :external_id

      attributes :email, :chapter_ids

      attribute :subscriptions do |user|
        user.subscriptions_dataset.map do |subscription|
          {
            id: subscription.uuid,
            subscription_type: subscription.subscription_type.name,
            active: subscription.active,
          }
        end
      end
    end
  end
end
