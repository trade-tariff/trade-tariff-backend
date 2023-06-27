module Api
  module Admin
    class AdminController < ApiController
      def set_cache_headers
        no_store
      end
    end
  end
end
