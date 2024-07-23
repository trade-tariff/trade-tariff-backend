module Api
  module Admin
    module GreenLanes
      class UpdateNotificationSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_update_notification

        set_id :id

        attributes :measure_type_id,
                   :regulation_id,
                   :regulation_role,
                   :status

      end
    end
  end
end
