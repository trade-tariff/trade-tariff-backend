module TradeTariffBackend
  module Config
    module Authentication
      def cognito_user_pool_id
        ENV['COGNITO_USER_POOL_ID']
      end

      def identity_encryption_secret
        ENV['IDENTITY_ENCRYPTION_SECRET']
      end

      def identity_api_host
        ENV['IDENTITY_API_HOST']
      end

      def identity_api_key
        ENV['IDENTITY_API_KEY']
      end

      def internal_ca_pem
        ENV['INTERNAL_CA_PEM'].presence&.gsub('\n', "\n")
      end
    end
  end
end
