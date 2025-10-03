module Api
  module User
    class PublicUserSerializer
      include JSONAPI::Serializer

      set_type :user

      set_id :external_id

      attributes :email, :chapter_ids, :stop_press_subscription

      attribute :active_commodity_codes do |object|
        object.active_commodity_codes.fetch(:active, [])
      end

      attribute :expired_commodity_codes do |object|
        object.active_commodity_codes.fetch(:expired, [])
      end

      attribute :erroneous_commodity_codes do |object|
        object.active_commodity_codes.fetch(:erroneous, [])
      end
    end
  end
end
