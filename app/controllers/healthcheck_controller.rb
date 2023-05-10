class HealthcheckController < ApplicationController
  skip_before_action :maintenance_mode_if_active

  def index
    if result[:healthy] == true
      render :success, json: result
    else
      render status: :service_unavailable, json: result
    end
  end

  private

  def result
    @result ||= Healthcheck.check
  end
end
