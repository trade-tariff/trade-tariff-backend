require 'digest'

module VatGuidance
  class QuestionJourneyGenerationSweep
    MAX_FINDING_LENGTH = 500

    def initialize(packet_artifact, ai_client: TradeTariffBackend.ai_client, model: 'gpt-5.4', reasoning_effort: 'high')
      @packet_artifact = packet_artifact.deep_stringify_keys
      @ai_client = ai_client
      @model = model
      @reasoning_effort = reasoning_effort
    end

    def call
      journeys = []
      attempts = generation_packets.map do |packet|
        generate_packet(packet, journeys)
      end
      {
        'source_packets_sha256' => packet_artifact.fetch('content_sha256'),
        'generation_metadata' => generation_metadata,
        'journeys' => journeys,
        'packet_generation_attempts' => attempts,
        'spike_findings' => [],
      }
    end

  private

    attr_reader :packet_artifact, :ai_client, :model, :reasoning_effort

    def generation_packets
      packets = packet_artifact.fetch('packets') + packet_artifact.fetch('commodity_packets') +
        packet_artifact.fetch('comparisons').flat_map { |comparison| [comparison.fetch('local_only'), comparison.fetch('reference_expanded')] }
      packets.uniq { |packet| packet.fetch('packet_id') }
    end

    def generate_packet(packet, journeys)
      journey = QuestionJourneyGenerator.new(packet, ai_client:, model:, reasoning_effort:).call.deep_dup
      journey['comparison_role'] = comparison_roles[packet.fetch('packet_id')] if comparison_roles.key?(packet.fetch('packet_id'))
      journeys << journey
      attempt(
        packet,
        'journey_generated',
        [journey.fetch('journey_id')],
        nil,
        model_response_sha256: content_sha256(journey),
      )
    rescue QuestionJourneyGenerator::GenerationError => e
      attempt(
        packet,
        'generation_failed',
        [],
        "#{e.class}: #{e.message}".truncate(MAX_FINDING_LENGTH),
        model_response_sha256: nil,
      )
    end

    def attempt(packet, status, journey_ids, finding, model_response_sha256:)
      {
        'packet_id' => packet.fetch('packet_id'),
        'source_packet_sha256' => packet.fetch('content_sha256'),
        'method' => 'llm_generation',
        'model_response_sha256' => model_response_sha256,
        'status' => status,
        'journey_ids' => journey_ids,
        'finding' => finding,
      }
    end

    def content_sha256(value)
      Digest::SHA256.hexdigest(JSON.generate(deep_sort(value)))
    end

    def deep_sort(value)
      case value
      when Hash then value.keys.sort.index_with { |key| deep_sort(value.fetch(key)) }
      when Array then value.map { |item| deep_sort(item) }
      else value
      end
    end

    def comparison_roles
      @comparison_roles ||= packet_artifact.fetch('comparisons').sole.then do |comparison|
        {
          comparison.fetch('local_only').fetch('packet_id') => 'catering_local_only',
          comparison.fetch('reference_expanded').fetch('packet_id') => 'catering_reference_expanded',
        }
      end
    end

    def generation_metadata
      {
        'ticket' => 'AI-1145',
        'generation_mode' => 'llm_generation_sweep',
        'provider' => 'OpenAI',
        'model' => model,
        'prompt_sha256' => Digest::SHA256.hexdigest(QuestionJourneyContract.generation_prompt),
        'human_review_required' => true,
      }
    end
  end
end
