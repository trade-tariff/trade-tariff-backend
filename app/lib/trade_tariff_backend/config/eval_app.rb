module TradeTariffBackend
  module Config
    module EvalApp
      def eval_app_url
        ENV['EVAL_APP_URL']
      end

      def eval_app_auth_token
        ENV['EVAL_APP_AUTH_TOKEN']
      end

      # /start is fire-and-forget (the eval app does the real work in a background task and
      # returns immediately) — so these stay short rather than matching OpenaiClient's much
      # longer, LLM-tuned timeouts. A slow/unreachable eval app should fail fast and visibly
      # (EvalAppClient turns the resulting Faraday::TimeoutError into a `failed` run), not hold a
      # Puma thread, and the admin app's own HTTP client, open for the whole launch request.
      def eval_app_timeout
        ENV.fetch('EVAL_APP_TIMEOUT', '5').to_i
      end

      def eval_app_open_timeout
        ENV.fetch('EVAL_APP_OPEN_TIMEOUT', '3').to_i
      end
    end
  end
end
