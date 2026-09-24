RSpec.describe SearchExport::JourneyProjection do
  let(:response) do
    {
      data: [{ attributes: { goods_nomenclature_item_id: '0207141000', classification_description: 'Frozen cuts', confidence: 'good', score: 1 } }],
      meta: { interactive_search: { answers: [{ question: 'Cut?', options: %w[Fillet], answer: 'Fillet' }], result_limit: 0 } },
    }
  end

  before do
    TradeTariffRequest.request_source = 'frontend'
    TradeTariffRequest.search_failures = []
  end

  it 'does not propagate capture failures into a search response' do
    allow(SearchExport::Journey).to receive(:upsert_terminal).and_raise(Sequel::DatabaseError, 'private details')
    allow(Rails.logger).to receive(:warn)

    expect { described_class.record(response:, query: 'chicken', answers: [], expansion_terms: [], request_id: 'journey-1') }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with('Could not capture classifier journey: Sequel::DatabaseError')
  end

  it 'does not replace a search failure with an omission-write failure' do
    allow(SearchExport::Journey).to receive(:omit).and_raise(Sequel::DatabaseError)

    expect { described_class.omit('journey-1') }.not_to raise_error
  end

  it 'stores the final answer for a frontend result and ignores admin traffic' do
    described_class.record(response:, query: 'frozen chicken', answers: [{ question: 'Cut?', options: %w[Fillet], answer: 'Fillet' }], expansion_terms: [], request_id: 'journey-1')

    stored = SearchExport::Journey.first
    expect(stored.end_page_type).to eq('Result')
    expect(stored.answers.first['answer']).to eq('Fillet')

    TradeTariffRequest.request_source = 'admin'
    described_class.record(response:, query: 'other', answers: [], expansion_terms: [], request_id: 'admin-1')
    TradeTariffRequest.request_source = 'backend_only'
    described_class.record(response:, query: 'other', answers: [], expansion_terms: [], request_id: 'backend-1')

    expect(SearchExport::Journey.select_map(:request_id)).to eq(%w[journey-1])
  end

  it 'omits a stored frontend journey when a later search stage fails' do
    described_class.record(response:, query: 'chicken', answers: [], expansion_terms: [], request_id: 'journey-1')

    Search::Instrumentation.search_stage_failed(
      request_id: 'journey-1', search_type: 'interactive', failure_code: 'query_expansion_failed',
      error_type: 'Timeout', error_message: 'Timed out'
    )

    expect(SearchExport::Journey.first.omitted).to be(true)
  end

  it 'does not change a frontend journey for a failure from another request source' do
    described_class.record(response:, query: 'chicken', answers: [], expansion_terms: [], request_id: 'journey-1')
    TradeTariffRequest.request_source = 'admin'

    described_class.omit('journey-1')

    expect(SearchExport::Journey.first.omitted).to be(false)
  end

  it 'does not access the projection for XI failures' do
    allow(TradeTariffBackend).to receive(:uk?).and_return(false)
    allow(SearchExport::Journey).to receive(:omit)

    described_class.omit('journey-1')

    expect(SearchExport::Journey).not_to have_received(:omit)
  end

  it 'replaces an earlier row with the final answers' do
    described_class.record(response:, query: 'frozen chicken', answers: [{ question: 'Cut?', options: %w[Fillet Whole], answer: 'Whole' }], expansion_terms: [], request_id: 'journey-1')
    described_class.record(response:, query: 'frozen chicken', answers: [{ question: 'Cut?', options: %w[Fillet Whole], answer: 'Fillet' }], expansion_terms: ['poultry meat'], request_id: 'journey-1')

    expect(SearchExport::Journey.count).to eq(1)
    expect(SearchExport::Journey.first.answers.first['answer']).to eq('Fillet')
    expect(SearchExport::Journey.first.expansion_terms).to eq(['poultry meat'])
  end
end
