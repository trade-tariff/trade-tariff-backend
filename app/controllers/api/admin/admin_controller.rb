module Api
  module Admin
    class AdminController < ApiController
      include AdminApi.routes.url_helpers
      include Api::Admin::Serializable

      before_action :set_paper_trail_whodunnit

      no_caching

      WHODUNNIT_NAME_MAX_LENGTH = 255

    private

      def set_paper_trail_whodunnit
        TradeTariffRequest.whodunnit = request.headers['X-Whodunnit']
        TradeTariffRequest.whodunnit_name = whodunnit_name_from_header if TradeTariffRequest.whodunnit.present?
      end

      # Admin URL-encodes the name, because HTTP headers must be ASCII.
      # PostgreSQL text cannot store NUL bytes, so they are removed.
      def whodunnit_name_from_header
        name = request.headers['X-Whodunnit-Name'].to_s
        URI.decode_uri_component(name).scrub.delete("\u0000").strip.first(WHODUNNIT_NAME_MAX_LENGTH).presence
      end
    end
  end
end
