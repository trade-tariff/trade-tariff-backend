RSpec.describe VatGuidance::AnswerPathEnumerator do
  subject(:enumeration) { described_class.new(question_journeys).call }

  let(:question_journeys) do
    JSON.parse(File.read(VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance/question_journeys.json')))
  end

  it 'enumerates every terminal path and exclusion in the AI-1145 artifact' do
    paths = enumeration.fetch('answer_paths')

    expect(paths.size).to eq(53)
    expect(paths.count { |path| path.dig('terminal', 'type') == 'outcome' }).to eq(25)
    expect(paths.count { |path| path.dig('terminal', 'type') == 'fallthrough' }).to eq(28)
    expect(paths.filter_map { |path| path.dig('terminal', 'treatment') }.tally).to eq(
      'standard' => 13,
      'reduced' => 1,
      'zero' => 11,
    )
    expect(enumeration.fetch('exclusions').size).to eq(4)
  end

  it 'uses stable unique identities bound to the ordered answer path and source artifact' do
    first = enumeration.fetch('answer_paths')
    second = described_class.new(question_journeys.deep_dup).call.fetch('answer_paths')

    expect(first).to eq(second)
    expect(first.pluck('id').uniq.size).to eq(first.size)
    expect(first).to all(satisfy { |path| path.fetch('id') == "answer-path:#{path.fetch('subject_sha256')}" })
  end

  it 'records exactly one spike review category for every path' do
    reviews = enumeration.fetch('answer_paths').map { |path| path.fetch('review') }

    expect(reviews.pluck('kind').tally).to eq('disposition' => 50, 'connection_candidate' => 3)
    expect(reviews).to all(include('quote_support' => include('status' => 'pending_domain_review')))
  end

  it 'only originates measure connections from rule journeys' do
    paths = enumeration.fetch('answer_paths')
    candidates = paths.select { |path| path.dig('review', 'kind') == 'connection_candidate' }
    commodity_paths = paths.select { |path| path.dig('scope', 'type') == 'commodity' }
    comparison_paths = paths.select { |path| path.fetch('journey_id').start_with?('notice-709-1-catering-') }

    expect(candidates).to all(satisfy { |path| path.dig('scope', 'type') == 'notice' })
    expect(commodity_paths).to all(satisfy { |path| path.dig('review', 'kind') == 'disposition' })
    expect(comparison_paths).to all(satisfy { |path| path.dig('review', 'kind') == 'disposition' })
  end

  it 'rejects a cycle instead of presenting a partial inventory' do
    journey = question_journeys.fetch('journeys').first
    journey.fetch('questions').first.fetch('answers').first['next'] = {
      'type' => 'question',
      'id' => journey.fetch('root_question_id'),
    }

    expect { enumeration }.to raise_error(described_class::EnumerationError, /contains a cycle/)
  end
end
