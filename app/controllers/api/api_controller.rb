module Api
  class ApiController < ApplicationController
    include GDS::SSO::ControllerMethods
    include EtagCaching

    respond_to :json

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
