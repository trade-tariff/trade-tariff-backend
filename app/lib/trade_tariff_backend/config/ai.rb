module TradeTariffBackend
  module Config
    module Ai
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
        'https://gb.api.openai.com/v1'
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

      # Spike: OpenAI models on Amazon Bedrock, selected per model (see BedrockOpenaiClient).
      def bedrock_api_key
        ENV['AWS_BEARER_TOKEN_BEDROCK']
      end

      def bedrock_region
        ENV.fetch('BEDROCK_REGION', 'eu-west-2')
      end

      def bedrock_api_base_url
        "https://bedrock-runtime.#{bedrock_region}.amazonaws.com/openai/v1"
      end
    end
  end
end
