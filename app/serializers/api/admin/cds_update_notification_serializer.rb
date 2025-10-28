module Api
  module Admin
    class CdsUpdateNotificationSerializer
      include JSONAPI::Serializer

      set_type :cds_update_notification

      set_id :id

      attributes :filename, :user_id, :enqueued_at
    end
  end
end
