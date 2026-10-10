# Spike: sends guided-search LLM calls to OpenAI GPT-5.6 models on Amazon Bedrock.
#
# Selected per model: TradeTariffBackend.search_ai_client routes `bedrock/…` keys
# from OpenaiClient::MODEL_CONFIGS here, so an evaluation run can compare the same
# model on OpenAI and Bedrock by overriding question_model.
#
# Uses Bedrock's OpenAI-compatible Responses API, because Bedrock only applies
# prompt caching to GPT-5.6 on that API (Chat Completions gets none).
class BedrockOpenaiClient < OpenaiClient
  UnknownModelError = Class.new(ArgumentError)

  # MODEL_CONFIGS key => Bedrock global cross-Region inference profile ID.
  BEDROCK_MODEL_IDS = {
    'bedrock/gpt-5.6-sol' => 'global.openai.gpt-5.6-sol',
    'bedrock/gpt-5.6-terra' => 'global.openai.gpt-5.6-terra',
    'bedrock/gpt-5.6-luna' => 'global.openai.gpt-5.6-luna',
  }.freeze

  def self.bedrock_model?(model)
    BEDROCK_MODEL_IDS.key?(model.to_s)
  end

  def call(context, model: nil, **options)
    bedrock_model_id = BEDROCK_MODEL_IDS.fetch(model.to_s) do
      raise UnknownModelError, "No Bedrock model for #{model.inspect}"
    end

    super(context, **options, model: bedrock_model_id)
  end

  class << self
    def api_base_url
      TradeTariffBackend.bedrock_api_base_url
    end

    def api_key
      TradeTariffBackend.bedrock_api_key
    end
  end

private

  def request_path
    'responses'
  end

  def request_body(messages:, model:, reasoning_effort:)
    body = {
      model: model,
      input: messages,
      safety_identifier: TradeTariffBackend.openai_user,
      text: { format: { type: 'json_object' } },
    }
    body[:reasoning] = { effort: reasoning_effort } if reasoning_effort.present?
    body
  end

  def response_content(body)
    texts = Array(body['output'])
      .select { |item| item['type'] == 'message' }
      .flat_map { |item| Array(item['content']) }
      .select { |content| content['type'] == 'output_text' }
      .map { |content| content['text'] }

    texts.join if texts.any?
  end

  def response_finish_reason(body)
    body['status']
  end
end
