class HealthcheckController < ApplicationController
  def index
    render json: Healthcheck.new.check
  end
end
