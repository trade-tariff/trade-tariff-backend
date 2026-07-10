module TradeTariffBackend
  module Config
    module AI
      def ai_model
        ENV.fetch('AI_MODEL', 'gpt-5.2')
      end

      def openai_user
        ENV.fetch('OPENAI_USER', 'hmrc-ott')
      end

      def openai_api_key
        ENV['OPENAI_API_KEY']
      end

      def openai_api_base_url
        ENV.fetch('OPENAI_API_BASE_URL', 'https://api.openai.com/v1')
      end

      def openai_api_timeout
        ENV.fetch('OPENAI_API_TIMEOUT', '180').to_i
      end

      def openai_api_open_timeout
        ENV.fetch('OPENAI_API_OPEN_TIMEOUT', '60').to_i
      end

      def openai_model_pricing
        Rails.application.config.x.openai_model_pricing || {}
      end
    end
  end
end
