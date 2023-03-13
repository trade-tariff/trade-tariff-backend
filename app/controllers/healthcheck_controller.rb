class HealthcheckController < ApplicationController
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
