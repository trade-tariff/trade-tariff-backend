module Api
  module Admin
    class AdminController < ApiController
      include AdminApi.routes.url_helpers

      before_action :set_paper_trail_whodunnit

      no_caching

      private

      def set_paper_trail_whodunnit
        Thread.current[:paper_trail_whodunnit] = request.headers['X-Whodunnit']
      end
    end
  end
end
