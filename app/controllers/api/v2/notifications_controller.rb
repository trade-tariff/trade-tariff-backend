module Api
  module V2
    class NotificationsController < ApplicationController
      CACHE_DURATION = 1.hour

      include ApiTokenAuthenticatable

      before_action :authenticate!

      def create
        if notification.valid?
          store_notification.tap do |notification|
            NotificationsWorker.perform_async(notification.id)

            render json: { data: { id: notification.id, type: 'notifications' } }, status: :accepted
          end
        else
          render json: Api::V2::ActiveModelErrorSerializationService.new(notification).call, status: :unprocessable_entity
        end
      end

      private

      def notification
        @notification ||= Notification.new(notification_params)
      end

      def store_notification
        TradeTariffBackend.redis.set(
          "notification_#{notification.id}",
          notification.to_json,
          ex: CACHE_DURATION.to_i,
        )

        notification
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
