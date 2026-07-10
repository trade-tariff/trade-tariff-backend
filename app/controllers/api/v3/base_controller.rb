module Api
  module V3
    class BaseController < ApplicationController
      rescue_from StandardError, with: :render_internal_server_error
      rescue_from Sequel::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

    private

      def render_not_found(exception = nil)
        render_error(
          status: :not_found,
          error: 'not_found',
          message: exception&.message || 'Resource not found',
        )
      end

      def render_bad_request(exception = nil)
        render_error(
          status: :bad_request,
          error: 'bad_request',
          message: exception&.message || 'Bad request',
        )
      end

      def render_internal_server_error(exception = nil)
        Rails.logger.error(exception&.message)
        Rails.logger.error(exception&.backtrace&.first(10)&.join("\n"))
        render_error(
          status: :internal_server_error,
          error: 'internal_server_error',
          message: 'An unexpected error occurred',
        )
      end

      def render_error(status:, error:, message:)
        status_code = Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(status, status)
        render json: { error:, message:, status: status_code }, status:
      end
    end
  end
end
