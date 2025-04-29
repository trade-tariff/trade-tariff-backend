module Api
  module V2
    class SubscriptionsController < ApplicationController
      before_action :load_subscription, only: %i[unsubscribe destroy]

      def index
        @subscriptions = PublicUsers::Subscription.where(user_id: params[:user_id])
        render json: @subscriptions
      end

      def unsubscribe
        return_on_invalid_subscription

        @subscription.deactivate!
        render json: @subscription
      end

      def destroy
        return_on_invalid_subscription

        @subscription.destroy
        render json: @subscription
      end

  private

      def load_subscription
        @subscription = PublicUsers::Subscription.find_by_id_and_user_id(params[:id], params[:user_id])
      end

      def return_on_invalid_subscription
        render json: { error: 'Subscription not found' }, status: :not_found unless @subscription
      end
    end
  end
end
