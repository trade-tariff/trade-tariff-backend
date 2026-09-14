RSpec.describe VatGuidance::QuestionJourneyGenerator do
  subject(:generate) do
    described_class.new(packet, ai_client:, model: 'test-model', reasoning_effort: 'low').call
  end

  let(:packet) do
    {
      'packet_id' => 'packet-1',
      'source' => {
        'node_type' => 'commodity',
        'chapter' => '20',
        'commodity_code' => '2000000000',
        'heading' => 'Example food',
      },
      'content' => [
        {
          'node_id' => 'node-1',
          'guide_key' => 'guide-1',
          'section_key' => 'section-1',
          'text' => 'Qualifying supplies are zero-rated.',
        },
      ],
    }
  end
  let(:evidence) do
    { 'quote' => 'Qualifying supplies are zero-rated.', 'node_id' => 'node-1', 'guide_key' => 'guide-1', 'section_key' => 'section-1' }
  end
  let(:journey) do
    {
      'journey_id' => 'generated-1',
      'source_packet_id' => 'packet-1',
      'scope' => { 'type' => 'commodity', 'chapter' => '20', 'commodity_code' => '2000000000', 'label' => 'Example food' },
      'relief_rule_ids' => %w[q1],
      'composition_required' => false,
      'fallthrough_targets' => [],
      'root_question_id' => 'q1',
      'questions' => [
        {
          'id' => 'q1',
          'prompt' => 'Does it qualify?',
          'evidence' => evidence,
          'answers' => [
            { 'id' => 'yes', 'label' => 'Yes', 'relief_disposition' => 'qualified', 'next' => { 'type' => 'outcome', 'id' => 'zero' } },
            { 'id' => 'no', 'label' => 'No', 'relief_disposition' => 'declined', 'next' => { 'type' => 'outcome', 'id' => 'standard' } },
          ],
        },
      ],
      'outcomes' => [
        { 'id' => 'zero', 'treatment' => 'zero', 'basis' => 'explicit_guidance', 'evidence' => evidence },
        { 'id' => 'standard', 'treatment' => 'standard', 'basis' => 'exhaustive_default', 'relief_question_ids' => %w[q1], 'evidence' => evidence },
      ],
      'exclusions' => [],
    }
  end
  let(:ai_client) { instance_double(OpenaiClient, call: journey) }

  it 'prompts the configured model and returns only a contract-valid tree' do
    expect(generate).to eq(journey)
    expect(ai_client).to have_received(:call).with(
      include(
        hash_including(
          role: 'system',
          content: match(
            /standard, reduced, zero, or exempt.*fallthrough next object has exactly type, id,\s+trader_visible, and reason/m,
          ),
        ),
      ),
      model: 'test-model',
      reasoning_effort: 'low',
      event_kind: 'vat_question_journey_generation',
    )
  end

  it 'also accepts a JSON string from compatible client adapters' do
    allow(ai_client).to receive(:call).and_return(journey.to_json)

    expect(generate).to eq(journey)
  end

  it 'rejects malformed model output before it becomes an artifact' do
    journey.fetch('outcomes').first['treatment'] = 'unknown'

    expect { generate }.to raise_error(VatGuidance::QuestionJourneyGenerator::GenerationError, /invalid treatment/)
  end

  it 'wraps a non-object model response in a generation error' do
    allow(ai_client).to receive(:call).and_return('[]')

    expect { generate }.to raise_error(VatGuidance::QuestionJourneyGenerator::GenerationError, /journey must be an object/)
  end

  it 'rejects an oversized model response before parsing it' do
    allow(ai_client).to receive(:call).and_return('x' * (described_class::MAX_RESPONSE_BYTES + 1))

    expect { generate }.to raise_error(VatGuidance::QuestionJourneyGenerator::GenerationError, /no larger than/)
  end

  it 'does not misclassify client configuration errors as packet generation failures' do
    allow(ai_client).to receive(:call).and_raise(ArgumentError, 'invalid client configuration')

    expect { generate }.to raise_error(ArgumentError, /invalid client configuration/)
  end

  it 'turns malformed relief id collections into a controlled generation error' do
    journey['relief_rule_ids'] = [{}, 'q1']
    journey.fetch('outcomes').last['relief_question_ids'] = 'q1'

    expect { generate }.to raise_error(
      VatGuidance::QuestionJourneyGenerator::GenerationError,
      /relief_rule_ids must contain only bounded, present strings/,
    )
  end
end
