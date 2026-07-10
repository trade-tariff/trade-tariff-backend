module TradeTariffBackend
  module Config
    module Reporting
      def frontend_host
        ENV['FRONTEND_HOST']
      end

      def reporting_cdn_host
        return ENV['REPORTING_CDN_HOST'] if ENV['REPORTING_CDN_HOST'].present?

        {
          'production' => 'https://reporting.trade-tariff.service.gov.uk',
          'staging' => 'https://reporting.staging.trade-tariff.service.gov.uk',
          'development' => 'https://reporting.dev.trade-tariff.service.gov.uk',
        }[environment.to_s]
      end
    end
  end
end
