module TradeTariffBackend
  module Config
    module GreenLanes
      def api_tokens
        ENV['GREEN_LANES_API_TOKENS']
      end

      def green_lanes_api_keys
        ENV.fetch('GREEN_LANES_API_KEYS', '{}')
      end

      def green_lanes_update_email
        ENV['GREEN_LANES_UPDATE_EMAIL']
      end

      def green_lanes_notify_measure_updates
        ENV.fetch('GREEN_LANES_NOTIFY_MEASURE_UPDATES', 'false') == 'true'
      end
    end
  end
end
