module Api
  module User
    class PublicUserSerializer
      include JSONAPI::Serializer

      set_type :user

      set_id :external_id

      attributes :email, :chapter_ids, :commodity_codes, :stop_press_subscription, :commodity_delta_subscription
    end
  end
end
