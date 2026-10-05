# Spike: sends guided-search LLM calls to OpenAI models on Amazon Bedrock, using
# Bedrock's OpenAI-compatible Chat Completions endpoint. Request and response
# shapes match OpenaiClient, so only the URL, API key and model change.
#
# The model selected in AdminConfiguration is used when Bedrock serves it from
# eu-west-2. Other models (e.g. gpt-5.2) fall back to
# TradeTariffBackend.bedrock_search_model.
class BedrockOpenaiClient < OpenaiClient
  # OpenAI model name => Bedrock global cross-Region inference profile ID.
  BEDROCK_MODEL_IDS = {
    'gpt-5.6' => 'global.openai.gpt-5.6-sol',
    'gpt-5.6-sol' => 'global.openai.gpt-5.6-sol',
    'gpt-5.6-terra' => 'global.openai.gpt-5.6-terra',
    'gpt-5.6-luna' => 'global.openai.gpt-5.6-luna',
  }.freeze

  def call(context, model: nil, **options)
    super(context, **options, model: BEDROCK_MODEL_IDS.fetch(model.to_s, TradeTariffBackend.bedrock_search_model))
  end

  class << self
    def api_base_url
      TradeTariffBackend.bedrock_api_base_url
    end

    def api_key
      TradeTariffBackend.bedrock_api_key
    end
  end
end
