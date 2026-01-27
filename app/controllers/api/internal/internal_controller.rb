module Api
  module Internal
    class InternalController < ApiController
      include InternalApi.routes.url_helpers

      no_caching
    end
  end
end
