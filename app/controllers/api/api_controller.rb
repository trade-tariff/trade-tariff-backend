module Api
  class ApiController < ApplicationController
    include GDS::SSO::ControllerMethods

    # We use ETags so this can be low, if the data hasn't changed and we've not
    # deployed then CloudFront will just receive a empty 304 response and there
    # will only be a single fast db query to check tariff_updates table
    CDN_CACHE_LIFETIME = 2.minutes

    etag { TradeTariffBackend.revision || Rails.env }
    before_action :set_cache_headers, if: :http_caching_enabled?

    respond_to :json

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

    def set_cache_headers
      set_cache_lifetime
      set_cache_etag
    end

    def set_cache_lifetime
      expires_in CDN_CACHE_LIFETIME, public: true
    end

    def set_cache_etag
      update = TariffSynchronizer::BaseUpdate.most_recent_applied
      fresh_when last_modified: update.applied_at, etag: update
    end

    def http_caching_enabled?
      Rails.configuration.action_controller.perform_caching
    end
  end
end
