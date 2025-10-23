module Api
  module V2
    class NotificationsController < ApplicationController
      include ApiTokenAuthenticatable

      before_action :authenticate!

      def create
        store_notification.tap do |notification_id|
          NotificationsWorker.perform_async(notification_id)

          render json: { data: { id: notification_id, type: 'notifications' } }, status: :accepted
        end
      end

      private

      def store_notification
        notification_id = SecureRandom.uuid
        Rails.cache.write("notification_#{notification_id}", notification_params.to_json, expires_in: 1.hour)

        notification_id
      end

      def notification_params
        params.require(:data).require(:attributes).permit(
          :email,
          :template_id,
          :email_reply_to_id,
          :reference,
          personalisation: {},
        )
      end
    end
  end
end
