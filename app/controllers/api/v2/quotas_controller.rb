module Api
  module V2
    class QuotasController < ApiController
      DEFAULT_INCLUDES = %w[
        quota_order_number
        quota_order_number.geographical_areas
        measures
        measures.goods_nomenclature
        measures.geographical_area
        incoming_quota_closed_and_transferred_event
        quota_order_number_origins
        quota_order_number_origins.geographical_area
        quota_order_number_origins.quota_order_number_origin_exclusions
        quota_order_number_origins.quota_order_number_origin_exclusions.geographical_area
      ].freeze

      ALLOWED_INCLUDES = %w[quota_balance_events].freeze

      before_action :validate_order_number, only: :search

      def search
        render json: serialized_quota_definitions
      end

      private

      def validate_order_number
        return if params[:order_number].blank?
        raise ActionController::BadRequest, params[:order_number] unless params[:order_number].match?(/\A\d{6}\z/)
      end

      def serialized_quota_definitions
        Api::V2::Quotas::QuotaDefinitionSerializer.new(
          quota_definitions, serializer_options
        ).serializable_hash
      end

      def quota_definitions
        search_service.call
      end

      def serializer_options
        {
          include: valid_includes,
          meta: {
            pagination: {
              page: current_page,
              per_page:,
              total_count: search_service.pagination_record_count,
            },
          },
        }
      end

      def search_service
        @search_service ||= QuotaSearchService.new(
          params,
          current_page,
          per_page,
          actual_date,
          include_quota_balance_events: include_params.include?('quota_balance_events'),
        )
      end

      def valid_includes
        return DEFAULT_INCLUDES if include_params.empty?

        valid_resources = include_params.select { |resource| ALLOWED_INCLUDES.include?(resource) }

        if valid_resources.length < include_params.length
          raise ArgumentError, "Error: invalid params in 'includes': #{invalid_includes}"
        end

        valid_resources
      end

      def invalid_includes
        include_params.reject { |resource| ALLOWED_INCLUDES.include?(resource) }
      end

      def actual_date
        Date.parse([params['year'], params['month'], params['day']].join('-'))
      rescue ArgumentError # empty date, default to as_of in ApplicationController
        super
      end

      def per_page
        5
      end
    end
  end
end
