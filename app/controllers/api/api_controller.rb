module Api
  class ApiController < ApplicationController
    include GDS::SSO::ControllerMethods

    respond_to :json

    skip_forgery_protection

    rescue_from Sequel::NoMatchingRow, Sequel::RecordNotFound do |_exception|
      serializer = TradeTariffBackend.error_serializer(request)
      render json: serializer.serialized_errors({ error: 'not found', url: request.url }), status: :not_found
    end

    rescue_from ActionController::ParameterMissing do |exception|
      serializer = TradeTariffBackend.error_serializer(request)
      render json: serializer.serialized_errors({ error: exception.message, url: request.url }), status: :unprocessable_entity
    end

    protected

    def current_page
      Integer(params[:page] || 1)
    rescue ArgumentError
      1
    end

    def per_page
      20
    end
    helper_method :current_page, :per_page

    def serialization_meta
      {
        meta: {
          pagination: {
            page: current_page,
            per_page: per_page,
            total_count: search_service.pagination_record_count
          }
        }
      }
    end
  end
end
