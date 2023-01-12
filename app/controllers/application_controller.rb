require 'clearable'

class ApplicationController < ActionController::Base
  respond_to :json, :html

  before_action :clear_association_queries
  around_action :configure_time_machine

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

  def clear_association_queries
    TradeTariffBackend.clearable_models.map(&:clear_association_cache)
  end
end
