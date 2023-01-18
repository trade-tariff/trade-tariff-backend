module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaDefinitionsController < ApiController
        before_action :authenticate_user!

        DEFAULT_INCLUDES = %w[quota_balance_events
                              quota_order_number_origins 
                              quota_unsuspension_events 
                              quota_reopening_events 
                              quota_unblocking_events 
                              quota_exhaustion_events 
                              quota_critical_events].freeze

        def current
          render json: serialized_quota_definition
        end

        private

        def serialized_quota_definition
          Api::Admin::QuotaOrderNumbers::QuotaDefinitionSerializer.new(quota_definition_or_not_found, serializer_options)
        end

        def quota_definition_or_not_found
          quota_definition.presence || (raise Sequel::RecordNotFound)
        end

        def quota_definition
          @quota_definition ||= QuotaOrderNumber
            .by_order_number(params[:id])
            .eager(quota_definition: :quota_balance_events)
            .actual
            .take
            .quota_definition
        end

        def serializer_options
          {
            include: DEFAULT_INCLUDES,
          }
        end
      end
    end
  end
end
