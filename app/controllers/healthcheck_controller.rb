class HealthcheckController < ApplicationController
  def index
    render json: Healthcheck.check
  end
end
