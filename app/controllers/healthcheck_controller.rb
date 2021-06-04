class HealthcheckController < ApplicationController
  def index
    Section.all
    render json: { git_sha1: CURRENT_REVISION }
  end
end
