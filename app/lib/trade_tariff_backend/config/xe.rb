module TradeTariffBackend
  module Config
    module Xe
      def xe_api_url
        ENV.fetch('XE_API_URL', 'https://xecdapi.xe.com')
      end

      def xe_api_username
        ENV['XE_API_USERNAME']
      end

      def xe_api_password
        ENV['XE_API_PASSWORD']
      end
    end
  end
end
