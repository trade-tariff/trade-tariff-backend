# rubocop:disable Rails/ApplicationController
class ErrorsController < ActionController::Base
  def bad_request
    respond_to_error \
      :bad_request,
      'Bad request: API documentation is available at https://api.trade-tariff.service.gov.uk/'
  end

  def not_found
    respond_to_error :not_found, 'Not Found'
  end

  def unprocessable_entity
    respond_to_error \
      :unprocessable_entity,
      'Unprocessable entity: API documentation is available at https://api.trade-tariff.service.gov.uk/'
  end

  def internal_server_error
    respond_to_error \
      :internal_server_error,
      'Internal Server Error: Please contact the Tariff team for help with this issue.'
  end

  def maintenance
    respond_to_error :service_unavailable, 'Service is unavailable'
  end

  def method_not_allowed
    respond_to_error \
      :method_not_allowed,
      'Method Not Allowed: API documentation is available at https://api.trade-tariff.service.gov.uk/'
  end

  def not_implemented
    respond_to_error \
      :not_implemented,
      'Not Implemented: API documentation is available at https://api.trade-tariff.service.gov.uk/'
  end

  def not_acceptable
    respond_to_error \
      :not_acceptable,
      'Not Acceptable: API documentation is available at https://api.trade-tariff.service.gov.uk/'
  end

private

  def respond_to_error(status, message)
    status_code = Rack::Utils.status_code(status)

    respond_to do |format|
      format.csv { render plain: %(Code,Error\n#{status_code},#{message}\n), status: }
      format.all { render json: serialize_errors(error: "#{status_code} - #{message}"), status: }
    end
  end

  def serialize_errors(errors)
    # TODO: Remove custom Accept header management
    if request.headers['Accept'] == 'application/vnd.uktt.v2'
      Api::V2::ErrorSerializationService.new.serialized_errors(errors)
    elsif request.url.include?('v2')
      Api::V2::ErrorSerializationService.new.serialized_errors(errors)
    else
      Api::V1::ErrorSerializationService.new.serialized_errors(errors)
    end
  end
end
# rubocop:enable Rails/ApplicationController
