class ApplicationController < ActionController::API
  include ActionController::Helpers
  include ::ActionController::MimeResponds
  # SequelRails incorrectly includes this into ActionController::Base but our
  # ApplicationController derives from ActionController::API
  include ::SequelRails::Railties::ControllerRuntime

  respond_to :json

  before_action :maintenance_mode_if_active
  around_action :configure_time_machine
  after_action  :check_query_count, if: -> { TradeTariffBackend.check_query_count? }

  def nothing
    head :ok
  end

  protected

  def append_info_to_payload(payload)
    super
    payload[:user_agent] = request.headers['HTTP_X_ORIGINAL_USER_AGENT'].presence || request.env['HTTP_USER_AGENT']
    payload[:client_id] = request.headers['HTTP_X_CLIENT_ID']
  end

  private

  def actual_date
    as_of_param = params[:as_of].to_s

    # Validate the format of the date using regex
    unless as_of_param.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      return Time.zone.today
    end

    date = Date.parse(as_of_param)

    # Ensure the date is within a 20-year range
    if date > 20.years.from_now
      Time.zone.today
    else
      date
    end
  rescue ArgumentError
    Time.zone.today
  end

  helper_method :actual_date

  def configure_time_machine(&block)
    TimeMachine.at(actual_date, &block)
  end

  def skip_time_machine(&block)
    TimeMachine.no_time_machine(&block)
  end

  def check_query_count
    QueryCountChecker.new(TradeTariffBackend.excess_query_threshold).check
  end

  def maintenance_mode_if_active
    MaintenanceMode.check! params[:maintenance_bypass]
  end
end
