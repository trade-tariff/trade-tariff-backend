module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaDefinitionsController < AdminController
        before_action :authenticate_user!

        DEFAULT_EAGER_LOAD_GRAPH = [
          { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
          :quota_balance_events,
          :quota_critical_events,
          :quota_exhaustion_events,
          :quota_reopening_events,
          :quota_unblocking_events,
          :quota_unsuspension_events,
        ].freeze

        DEFAULT_INCLUDES = %w[
          measurement_unit
          quota_order_number
          quota_balance_events
          quota_critical_events
          quota_exhaustion_events
          quota_order_number_origins
          quota_reopening_events
          quota_unblocking_events
          quota_unsuspension_events
        ].freeze

        def index
          render json: serialized_quota_definitions
        end

        def show
          render json: serialized_quota_definition
        end

        private

        def serialized_quota_definitions
          Api::Admin::QuotaOrderNumbers::QuotaDefinitionSerializer.new(quota_definitions, serializer_options)
        end

        def serialized_quota_definition
          Api::Admin::QuotaOrderNumbers::QuotaDefinitionSerializer.new(quota_definition, serializer_options)
        end

        def serializer_options
          {
            include: DEFAULT_INCLUDES,
          }
        end

        def quota_definition
          @quota_definition ||= QuotaDefinition
            .where(
              quota_order_number_id: params[:quota_order_number_id],
              quota_definition_sid: params[:id],
            )
            .eager(*DEFAULT_EAGER_LOAD_GRAPH)
            .take
        end

        delegate :quota_definitions, to: :quota_order_number

        def quota_order_number
          @quota_order_number ||= QuotaOrderNumber
              .actual
              .by_order_number(params[:quota_order_number_id])
              .eager(
                [
                  { quota_definitions: DEFAULT_EAGER_LOAD_GRAPH },
                  :quota_order_number_origins,
                ],
              )
              .take
        end
      end
    end
  end
end
