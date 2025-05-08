module Api
  module V2
    class SubscriptionsController < ApplicationController
      before_action :load_subscription, only: %i[unsubscribe destroy]

      def index
        @subscriptions = PublicUsers::Subscription.where(user_id: params[:user_id])
        render json: @subscriptions
      end

      def unsubscribe
        @subscription.deactivate!
        render json: @subscription
      end

      def destroy
        @subscription.destroy
        head :ok
      end

  private

      def load_subscription
        @subscription = PublicUsers::Subscription.first(id: params[:id], user_id: params[:user_id])
        return_on_invalid_subscription if @subscription.nil?
        @subscription
      rescue StandardError
        return_on_invalid_subscription
      end

      def return_on_invalid_subscription
        render json: { error: 'Subscription not found' }, status: :not_found unless @subscription
      end
    end
  end
end
