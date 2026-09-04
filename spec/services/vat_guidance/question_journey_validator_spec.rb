RSpec.describe VatGuidance::QuestionJourneyValidator do
  subject(:result) { described_class.new(journey, packet).call }

  let(:node_id) { 'document:/guidance/example#section' }
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
          'node_id' => node_id,
          'guide_key' => 'guide-1',
          'section_key' => 'section',
          'text' => 'Qualifying supplies are zero-rated. Other cases continue to the next rule.',
        },
      ],
    }
  end
  let(:evidence) do
    {
      'quote' => 'Qualifying supplies are zero-rated.',
      'node_id' => node_id,
      'guide_key' => 'guide-1',
      'section_key' => 'section',
    }
  end
  let(:journey) do
    {
      'journey_id' => 'journey-1',
      'source_packet_id' => 'packet-1',
      'scope' => { 'type' => 'commodity', 'chapter' => '20', 'commodity_code' => '2000000000', 'label' => 'Example food' },
      'relief_rule_ids' => %w[qualifies],
      'composition_required' => false,
      'fallthrough_targets' => [],
      'root_question_id' => 'qualifies',
      'questions' => [
        {
          'id' => 'qualifies',
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
        {
          'id' => 'standard',
          'treatment' => 'standard',
          'basis' => 'exhaustive_default',
          'relief_question_ids' => %w[qualifies],
          'evidence' => evidence,
        },
      ],
      'exclusions' => [],
    }
  end

  it 'accepts a reachable tree with exact, located quotes and only contracted treatments' do
    expect(result).to be_valid
    expect(result.errors).to be_empty
  end

  it 'rejects treatments outside the four-value contract' do
    journey.fetch('outcomes').first['treatment'] = 'undecided'

    expect(result).not_to be_valid
    expect(result.errors).to include(/invalid treatment/)
  end

  it 'rejects a quote that is not verbatim in its declared packet node' do
    journey.fetch('questions').first.fetch('evidence')['quote'] = 'A paraphrase'

    expect(result.errors).to include(/not verbatim/)
  end

  it 'rejects a quote attributed to a node outside the packet' do
    journey.fetch('outcomes').first.fetch('evidence')['node_id'] = 'document:/elsewhere#section'

    expect(result.errors).to include(/not declared in the packet/)
  end

  it 'rejects numerical rate fields on outcomes' do
    journey.fetch('outcomes').first['percentage'] = 0

    expect(result.errors).to include(/unknown fields/, /rate-like field/)
  end

  it 'rejects numerical rates hidden in nested unknown fields' do
    journey['metadata'] = { 'display' => 'VAT is 20%' }

    expect(result.errors).to include(/unknown fields/, /numerical percentage/)
  end

  it 'binds commodity scope to the supplied packet source' do
    journey.fetch('scope')['commodity_code'] = '2099999999'

    expect(result.errors).to include(/commodity_code does not match packet source/)
  end

  it 'requires the exact commodity scope shape' do
    journey.fetch('scope')['notice_number'] = '701/14'

    expect(result.errors).to include(/commodity scope has unknown fields: notice_number/)
  end

  it 'binds notice labels and exact scope shape to the packet source' do
    packet['source'] = {
      'node_type' => 'section',
      'guide_key' => 'vat-notice-701-14',
      'heading' => 'Food products',
    }
    journey['scope'] = {
      'type' => 'notice',
      'notice_number' => '701/14',
      'label' => 'Fabricated label',
      'chapter' => '20',
    }

    expect(result.errors).to include(
      /notice scope has unknown fields: chapter/,
      /scope label does not match packet source/,
    )
  end

  it 'rejects trader-visible fallthrough' do
    journey['composition_required'] = true
    journey['fallthrough_targets'] = [
      { 'id' => 'next-rule', 'resolution' => 'module_boundary', 'required_composer' => 'AI-1146' },
    ]
    journey.fetch('questions').first.fetch('answers').last['next'] = {
      'type' => 'fallthrough',
      'id' => 'next-rule',
      'trader_visible' => true,
      'reason' => 'Rule declined',
    }
    journey.fetch('questions').first.fetch('answers').last['relief_disposition'] = 'declined'
    journey.fetch('outcomes').pop

    expect(result.errors).to include(/fallthrough must not be trader-visible/)
  end

  it 'rejects internal fallthrough fields on question and outcome transitions' do
    journey.fetch('questions').first.fetch('answers').first['next']['trader_visible'] = false
    journey.fetch('questions').first.fetch('answers').first['next']['reason'] = 'Not a fallthrough'

    expect(result.errors).to include(/transition has unknown fields: trader_visible, reason/)
  end

  it 'accepts hidden fallthrough only when later composition is declared' do
    journey['composition_required'] = true
    journey['fallthrough_targets'] = [
      { 'id' => 'next-rule', 'resolution' => 'module_boundary', 'required_composer' => 'AI-1146' },
    ]
    journey.fetch('questions').first.fetch('answers').last['next'] = {
      'type' => 'fallthrough',
      'id' => 'next-rule',
      'trader_visible' => false,
      'reason' => 'Rule declined',
    }
    journey.fetch('questions').first.fetch('answers').last['relief_disposition'] = 'declined'
    journey.fetch('outcomes').pop

    expect(result).to be_valid
  end

  it 'rejects a fallthrough assigned to an unapproved composer' do
    journey['composition_required'] = true
    journey['fallthrough_targets'] = [
      { 'id' => 'next-rule', 'resolution' => 'module_boundary', 'required_composer' => 'unapproved-composer' },
    ]
    answer = journey.fetch('questions').first.fetch('answers').last
    answer['relief_disposition'] = 'declined'
    answer['next'] = {
      'type' => 'fallthrough',
      'id' => 'next-rule',
      'trader_visible' => false,
      'reason' => 'Rule declined',
    }
    journey.fetch('outcomes').pop

    expect(result.errors).to include(/must declare the AI-1146 module boundary/)
  end

  it 'rejects a question cycle' do
    journey.fetch('questions').first.fetch('answers').first['next'] = { 'type' => 'question', 'id' => 'qualifies' }
    journey.fetch('outcomes').shift

    expect(result.errors).to include(/contains a cycle/)
  end

  it 'rejects standard-by-default when a declared relief question was skipped' do
    journey.fetch('outcomes').last['relief_question_ids'] = %w[qualifies another-relief]

    expect(result.errors).to include(/does not prove the journey's full relief rule set/)
  end

  it 'rejects standard-by-default unless every relief answer on that path declined' do
    journey.fetch('questions').first.fetch('answers').last['relief_disposition'] = 'qualified'

    expect(result.errors).to include(/without every relief rule declining/)
  end

  it 'rejects an undeclared hidden fallthrough target' do
    journey['composition_required'] = true
    journey.fetch('questions').first.fetch('answers').last['next'] = {
      'type' => 'fallthrough',
      'id' => 'arbitrary-rule',
      'trader_visible' => false,
      'reason' => 'Rule declined',
    }
    journey.fetch('questions').first.fetch('answers').last['relief_disposition'] = 'declined'
    journey.fetch('outcomes').pop

    expect(result.errors).to include(/fallthrough target is not declared/)
  end

  it 'rejects a fallthrough that does not explicitly decline the relief rule' do
    journey['composition_required'] = true
    journey['fallthrough_targets'] = [
      { 'id' => 'next-rule', 'resolution' => 'module_boundary', 'required_composer' => 'AI-1146' },
    ]
    answer = journey.fetch('questions').first.fetch('answers').last
    answer['relief_disposition'] = 'qualified'
    answer['next'] = {
      'type' => 'fallthrough',
      'id' => 'next-rule',
      'trader_visible' => false,
      'reason' => 'Rule declined',
    }
    journey.fetch('outcomes').pop

    expect(result.errors).to include(/fallthrough must declare relief_disposition declined/)
  end

  it 'rejects textual numerical rates outside verbatim evidence' do
    journey.fetch('questions').first['prompt'] = 'Should the stored VAT rate be 20 percent?'

    expect(result.errors).to include(/stores a numerical percentage/)
  end

  it 'rejects arbitrary number words used as stored rates outside verbatim evidence' do
    ['fifteen percent', 'one hundred per cent', 'twenty-five percentage', 'half per cent', 'one-half percent', '½%'].each do |stored_rate|
      candidate = journey.deep_dup
      candidate.fetch('questions').first['prompt'] = "Is the VAT rate #{stored_rate}?"

      validation = described_class.new(candidate, packet).call
      expect(validation.errors).to include(/stores a numerical percentage/)
    end
  end

  it 'allows numerical rates inside verbatim evidence quotes' do
    packet.fetch('content').first['text'] = 'Qualifying supplies are zero-rated at fifteen percent.'
    journey.fetch('questions').first.fetch('evidence')['quote'] = 'Qualifying supplies are zero-rated at fifteen percent.'

    expect(result).to be_valid
  end

  it 'requires every declared top-level journey contract field' do
    journey.delete('relief_rule_ids')
    journey.delete('composition_required')
    journey.delete('fallthrough_targets')

    expect { result }.not_to raise_error
    expect(result.errors).to include(
      /missing required fields:.*composition_required.*fallthrough_targets.*relief_rule_ids/,
      /composition_required must be true or false/,
    )
  end

  it 'requires composition_required to be boolean' do
    journey['composition_required'] = 'false'

    expect(result.errors).to include(/composition_required must be true or false/)
  end

  it 'returns controlled validation errors for malformed generated shapes' do
    journey['questions'] = %w[not-an-object]

    expect { result }.not_to raise_error
    expect(result.errors).to include(/each question must be an object/)
  end

  it 'returns controlled errors for scalar and mixed-type relief id collections' do
    journey['relief_rule_ids'] = 'qualifies'
    journey.fetch('outcomes').last['relief_question_ids'] = [{}, 'qualifies']

    expect { result }.not_to raise_error
    expect(result.errors).to include(
      /relief_rule_ids must be an array/,
      /relief_question_ids must contain only bounded, present strings/,
    )
  end

  it 'rejects non-string and oversized ids and text' do
    journey['journey_id'] = 123
    journey.fetch('questions').first['id'] = 'q' * (described_class::MAX_ID_LENGTH + 1)
    journey.fetch('questions').first['prompt'] = 'p' * (described_class::MAX_TEXT_LENGTH + 1)

    expect { result }.not_to raise_error
    expect(result.errors).to include(
      /journey_id must be a bounded, present string/,
      /question id must be a bounded, present string/,
      /prompt must be a present string/,
    )
  end
end
