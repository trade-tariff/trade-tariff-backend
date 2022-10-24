module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaDefinitionsController < ApiController
        DEFAULT_INCLUDES = %w[quota_definition.quota_balance_events].freeze

        def current
          render json: serialized_quota_order_number
        end

        private

        def serialized_quota_order_number
          Api::Admin::QuotaOrderNumbers::QuotaOrderNumberSerializer.new(quota_order_number, serializer_options)
        end

        def quota_order_number
          @quota_order_number ||= QuotaOrderNumber
            .by_order_number(params[:id])
            .eager(quota_definition: :quota_balance_events)
            .take
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
