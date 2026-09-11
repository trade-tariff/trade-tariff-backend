RSpec.describe VatGuidance::QuestionJourneyGenerationSweep do
  subject(:result) do
    described_class.new(packet_artifact, ai_client:, model: 'test-model', reasoning_effort: 'low').call
  end

  let(:packet) do
    {
      'packet_id' => 'packet-1',
      'content_sha256' => 'a' * 64,
      'source' => { 'node_type' => 'notice', 'guide_key' => 'guide-1', 'section_key' => 'section-1' },
      'content' => [],
    }
  end
  let(:packet_artifact) do
    {
      'content_sha256' => 'b' * 64,
      'packets' => [packet],
      'commodity_packets' => [],
      'comparisons' => [{ 'local_only' => packet, 'reference_expanded' => packet }],
    }
  end
  let(:journey) { { 'journey_id' => 'journey-1' } }
  let(:generator) { instance_double(VatGuidance::QuestionJourneyGenerator, call: journey) }
  let(:ai_client) { instance_double(OpenaiClient) }

  before do
    allow(VatGuidance::QuestionJourneyGenerator).to receive(:new).and_return(generator)
  end

  it 'records one explicit, hash-bound attempt for each unique packet' do
    expect(result.fetch('journeys')).to eq([journey.merge('comparison_role' => 'catering_reference_expanded')])
    expect(result.fetch('packet_generation_attempts')).to contain_exactly(
      include(
        'packet_id' => 'packet-1',
        'source_packet_sha256' => 'a' * 64,
        'method' => 'llm_generation',
        'model_response_sha256' => match(/\A[0-9a-f]{64}\z/),
        'status' => 'journey_generated',
        'journey_ids' => %w[journey-1],
        'finding' => nil,
      ),
    )
  end

  it 'records a bounded failure instead of silently claiming packet coverage' do
    allow(generator).to receive(:call).and_raise(VatGuidance::QuestionJourneyGenerator::GenerationError, 'invalid tree')

    expect(result.fetch('journeys')).to be_empty
    expect(result.fetch('packet_generation_attempts')).to contain_exactly(
      include('status' => 'generation_failed', 'journey_ids' => [], 'finding' => /invalid tree/),
    )
    expect(result.dig('packet_generation_attempts', 0, 'model_response_sha256')).to be_nil
  end

  it 'identifies the output as an executed LLM sweep rather than a manual review disposition' do
    expect(result.dig('generation_metadata', 'generation_mode')).to eq('llm_generation_sweep')
    expect(result.fetch('packet_generation_attempts')).to all(include('method' => 'llm_generation'))
  end

  it 'hashes the normalized journey deterministically for audit provenance' do
    differently_ordered_journey = { 'journey_id' => 'journey-1', 'scope' => { 'b' => 2, 'a' => 1 } }
    allow(generator).to receive(:call).and_return(differently_ordered_journey)
    first_hash = result.dig('packet_generation_attempts', 0, 'model_response_sha256')

    allow(generator).to receive(:call).and_return(
      { 'scope' => { 'a' => 1, 'b' => 2 }, 'journey_id' => 'journey-1' },
    )

    second_result = described_class.new(packet_artifact, ai_client:).call
    expect(second_result.dig('packet_generation_attempts', 0, 'model_response_sha256')).to eq(first_hash)
  end

  it 'continues after a packet-specific generation error' do
    second_packet = packet.merge('packet_id' => 'packet-2', 'content_sha256' => 'c' * 64)
    packet_artifact['packets'] << second_packet
    calls = 0
    allow(generator).to receive(:call) do
      calls += 1
      raise VatGuidance::QuestionJourneyGenerator::GenerationError, 'invalid tree' if calls == 1

      journey
    end

    expect(result.fetch('packet_generation_attempts')).to contain_exactly(
      include('packet_id' => 'packet-1', 'status' => 'generation_failed'),
      include('packet_id' => 'packet-2', 'status' => 'journey_generated'),
    )
  end

  it 'fails fast when the provider call fails systemically' do
    second_packet = packet.merge('packet_id' => 'packet-2', 'content_sha256' => 'c' * 64)
    packet_artifact['packets'] << second_packet
    provider_error = OpenaiClient::ApiError.new(status: 401, body: 'invalid credentials')
    allow(generator).to receive(:call).and_raise(provider_error)

    expect { result }.to raise_error(provider_error)
    expect(VatGuidance::QuestionJourneyGenerator).to have_received(:new).once
  end
end
