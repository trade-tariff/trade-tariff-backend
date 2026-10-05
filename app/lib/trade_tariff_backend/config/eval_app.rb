module TradeTariffBackend
  module Config
    module EvalApp
      def eval_app_url
        ENV.fetch('EVAL_APP_URL')
      end

      def eval_app_auth_token
        ENV['EVAL_APP_AUTH_TOKEN']
      end
    end
  end
end
