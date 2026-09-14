module VatGuidance
  class QuestionJourneyGenerator
    GenerationError = Class.new(StandardError)
    MAX_RESPONSE_BYTES = 1_000_000

    def initialize(packet, ai_client: TradeTariffBackend.ai_client, model: 'gpt-5.4', reasoning_effort: 'high')
      @packet = packet.deep_stringify_keys
      @ai_client = ai_client
      @model = model
      @reasoning_effort = reasoning_effort
    end

    def call
      response = ai_client.call(
        messages,
        model: model,
        reasoning_effort: reasoning_effort,
        event_kind: 'vat_question_journey_generation',
      )
      validate_response(response)
    end

  private

    attr_reader :packet, :ai_client, :model, :reasoning_effort

    def validate_response(response)
      journey = normalize_response(response)
      result = QuestionJourneyValidator.new(journey, packet).call
      raise GenerationError, result.errors.join('; ') unless result.valid?

      journey.deep_stringify_keys
    rescue JSON::ParserError, TypeError, NoMethodError, ArgumentError => e
      raise GenerationError, "Invalid model response: #{e.message}"
    end

    def normalize_response(response)
      case response
      when Hash
        enforce_response_size!(JSON.generate(response))
        response.deep_stringify_keys
      when String
        enforce_response_size!(response)
        ExtractBottomJson.call(AiResponseSanitizer.call(response))
      else
        raise GenerationError, 'Model response must be a JSON object or JSON string'
      end
    end

    def enforce_response_size!(serialized_response)
      return if serialized_response.bytesize <= MAX_RESPONSE_BYTES

      raise GenerationError, "Model response must be no larger than #{MAX_RESPONSE_BYTES} bytes"
    end

    def messages
      [
        { role: 'system', content: QuestionJourneyContract.generation_prompt },
        { role: 'user', content: JSON.generate(packet) },
      ]
    end
  end
end
