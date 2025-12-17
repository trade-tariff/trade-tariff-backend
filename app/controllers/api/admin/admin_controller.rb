module Api
  module Admin
    class AdminController < ApiController
      include AdminApi.routes.url_helpers

      no_caching
    end
  end
end
