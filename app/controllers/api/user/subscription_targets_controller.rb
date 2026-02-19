module Api
  module User
    class SubscriptionTargetsController < UserController
      include Pageable

      before_action :find_subscription

      def index
        render json: serialize
      rescue PublicUsers::UnsupportedFilterServiceError, ArgumentError => e
        render json: serialize_errors({ error: e.message }), status: :bad_request
      end

      def download
        package = TimeMachine.now do
          Api::User::ActiveCommoditiesService.new(@subscription).generate_report
        end

        filename_date = TimeMachine.now { Time.zone.today.strftime('%Y-%m-%d') }

        send_data package.to_stream.read,
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: "attachment; filename=commodity_watch_list-your_codes_#{filename_date}.xlsx"
      end

      private

      def filter_params
        params.fetch(:filter, {}).permit(:active_commodities_type)
      end

      def filtered_targets
        @filtered_targets ||= @subscription.filter.call(
          filter_params[:active_commodities_type]&.to_sym,
          current_page,
          per_page,
        )
      end

      def serialize
        targets, @total = filtered_targets
        serialized_targets = Api::User::SubscriptionTargetSerializer.new(targets, include: [:target_object]).serializable_hash

        {
          data: serialized_targets[:data],
          included: serialized_targets[:included],
        }.merge(pagination_meta)
      end

      def record_count
        @total
      end

      def serialize_errors(errors)
        Api::User::ErrorSerializationService.new.serialized_errors(errors)
      end

      def find_subscription
        @subscription = current_user.subscriptions_dataset.where(uuid: subscription_id).first

        if @subscription.nil?
          render json: { message: 'No subscription ID was provided' }, status: :unauthorized and return
        end
      end

      def subscription_id
        params[:subscription_id]
      end
    end
  end
end
