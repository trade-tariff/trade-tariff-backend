module Api
  class ApiController < ApplicationController
    include EtagCaching

    respond_to :json

    rescue_from Sequel::NoMatchingRow, Sequel::RecordNotFound do |_exception|
      serializer = TradeTariffBackend.error_serializer(request)
      render json: serializer.serialized_errors({ error: 'not found', url: request.url }), status: :not_found
    end

    rescue_from ActionController::ParameterMissing, NotImplementedError do |exception|
      serializer = TradeTariffBackend.error_serializer(request)
      render json: serializer.serialized_errors({ error: exception.message, url: request.url }), status: :unprocessable_content
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
            per_page:,
            total_count: search_service.pagination_record_count,
          },
        },
      }
    end

    def include_params
      return [] if params[:include].blank?

      params[:include].split(',')
    end
  end
end
