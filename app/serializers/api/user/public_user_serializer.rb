module Api
  module User
    class PublicUserSerializer
      include JSONAPI::Serializer

      set_type :user

      set_id :external_id

      attributes :email, :chapter_ids, :stop_press_subscription, :active_commodity_codes, :expired_commodity_codes, :erroneous_commodity_codes
    end
  end
end
