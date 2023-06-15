class ApplicationController < ActionController::API
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
  end

  private

  def actual_date
    Date.parse(params[:as_of].to_s)
  rescue ArgumentError # empty as_of param means today
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
