module TradeTariffBackend
  module Config
    module ServiceContext
      def service
        ENV.fetch('SERVICE', 'uk')
      end

      def uk?
        service == 'uk'
      end

      def xi?
        service == 'xi'
      end

      def environment
        ActiveSupport::StringInquirer.new(ENV.fetch('ENVIRONMENT', 'local'))
      end

      def deployed_environment
        ENV.fetch('ENVIRONMENT', Rails.env)
      end

      def promote_customs_tariff_notes?
        !environment.production?
      end

      def currency
        SERVICE_CURRENCIES.fetch(service, 'GBP')
      end
    end
  end
end
