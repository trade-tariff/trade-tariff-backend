require 'clearable'

class ApplicationController < ActionController::Base
  respond_to :json, :html

  before_action :clear_association_queries
  around_action :configure_time_machine

  unless Rails.application.config.consider_all_requests_local
    rescue_from Exception,                          with: :render_internal_server_error
    rescue_from ArgumentError,                      with: :render_bad_request
    rescue_from Sequel::RecordNotFound,             with: :render_not_found
    rescue_from ActionController::RoutingError,     with: :render_not_found
    rescue_from AbstractController::ActionNotFound, with: :render_not_found
  end

  def render_not_found
    respond_to do |format|
      format.any do
        response.headers['Content-Type'] = 'application/json'
        serializer = TradeTariffBackend.error_serializer(request)
        render json: serializer.serialized_errors(error: '404 - Not Found'), status: :not_found
      end
    end
  end

  def render_bad_request(exception)
    logger.error exception
    logger.error exception.backtrace
    ::Raven.capture_exception(exception)

    respond_to do |format|
      format.any do
        response.headers['Content-Type'] = 'application/json'
        serializer = TradeTariffBackend.error_serializer(request)
        render json: serializer.serialized_errors(error: "400 - Bad request: #{exception.message}"), status: :bad_request
      end
    end
  end

  def render_internal_server_error(exception)
    logger.error exception
    logger.error exception.backtrace
    ::Raven.capture_exception(exception)

    respond_to do |format|
      format.any do
        response.headers['Content-Type'] = 'application/json'
        serializer = TradeTariffBackend.error_serializer(request)
        render json: serializer.serialized_errors(error: "500 - Internal Server Error: #{exception.message}"), status: :internal_server_error
      end
    end
  end

  def nothing
    head :ok
  end

  protected

  def append_info_to_payload(payload)
    super
    payload[:user_agent] = request.headers['HTTP_X_ORIGINAL_USER_AGENT'].presence || request.env['HTTP_USER_AGENT']
  end

  private

  def actual_date
    Date.parse(params[:as_of].to_s)
  rescue ArgumentError # empty as_of param means today
    Date.current
  end
  helper_method :actual_date

  def configure_time_machine(&block)
    TimeMachine.at(actual_date, &block)
  end

  def clear_association_queries
    TradeTariffBackend.clearable_models.map(&:clear_association_cache)
  end
end
