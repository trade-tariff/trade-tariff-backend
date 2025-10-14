module Api
  module Admin
    class CdsUpdateNotificationsController < AdminController
      before_action :authenticate_user!

      def create
        notification = CdsUpdateNotification.new(cds_update_notification_params[:attributes])

        if notification.valid?
          notification.save
          render json: Api::Admin::CdsUpdateNotificationSerializer.new(notification, { is_collection: false }).serializable_hash, status: :created, location: api_cds_update_notifications_url
        else
          render json: Api::Admin::ErrorSerializationService.new(notification).call, status: :unprocessable_content
        end
      end

      private

      def cds_update_notification_params
        params.require(:data).permit(:type, attributes: %i[filename user_id])
      end
    end
  end
end
