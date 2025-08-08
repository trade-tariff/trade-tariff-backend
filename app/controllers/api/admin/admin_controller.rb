module Api
  module Admin
    class AdminController < ApiController
      include GDS::SSO::ControllerMethods
      include AdminApi.routes.url_helpers

      no_caching
    end
  end
end
