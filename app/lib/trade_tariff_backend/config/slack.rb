module TradeTariffBackend
  module Config
    module Slack
      NON_PRODUCTION_ALERTS_CHANNEL = '#non-production-alerts'.freeze

      def slack_web_hook_url
        ENV['SLACK_WEB_HOOK_URL']
      end

      def slack_channel
        ENV.fetch('SLACK_CHANNEL', '#tariffs-etl')
      end

      def slack_username
        ENV.fetch('SLACK_USERNAME', 'Trade Tariff Backend')
      end

      def slack_failures_enabled?
        ENV.fetch('SLACK_FAILURES_ENABLED', 'false').to_s == 'true'
      end

      def slack_failures_channel
        ENV.fetch('SLACK_FAILURES_CHANNEL') { environment.production? ? '#production-alerts' : NON_PRODUCTION_ALERTS_CHANNEL }
      end

      def slack_observability_channel
        ENV.fetch('SLACK_OBSERVABILITY_CHANNEL') { environment.production? ? '#production-observability' : NON_PRODUCTION_ALERTS_CHANNEL }
      end
    end
  end
end
