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

        attribute :measure_type_description do |update|
          update.measure_type&.description
        end

        attribute :regulation_description do |update|
          update.regulation.try(:information_text)
        end

        attribute :regulation_url do |update|
          ApplicationHelper.regulation_url(update.regulation)
        end

        attribute :theme do |update|
          update.theme&.to_s
        end
      end
    end
  end
end
