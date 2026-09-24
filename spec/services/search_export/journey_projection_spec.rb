RSpec.describe SearchExport::JourneyProjection do
  let(:response) do
    {
      data: [{ attributes: { goods_nomenclature_item_id: '0207141000', classification_description: 'Frozen cuts', confidence: 'good', score: 1 } }],
      meta: { interactive_search: { result_limit: 0 } },
    }
  end
  let(:arguments) { { response:, query: 'cas 10310-21-1', answers: [{ question: 'Cut?', options: %w[Fillet Whole], answer: 'Fillet' }], expansion_terms: ['poultry meat'], request_id: 'journey-1' } }

  before do
    TradeTariffRequest.request_source = 'frontend'
    TradeTariffRequest.search_failures = []
    allow(Search::Instrumentation).to receive(:evaluation_journey_recorded)
  end

  it 'emits a self-contained trace without a database projection' do
    described_class.record(**arguments)

    expect(Search::Instrumentation).to have_received(:evaluation_journey_recorded).with(
      hash_including(query: 'cas 10310-21-1', expansion_terms: ['poultry meat'], end_page_type: 'Result',
                     answers: [{ 'question' => 'Cut?', 'options' => %w[Fillet Whole], 'answer' => 'Fillet' }],
                     results: [hash_including(commodity_code: '0207141000', description: 'Frozen cuts', confidence_label: 'Good')]),
    )
  end

  it 'isolates logging failures from search responses without printing private data' do
    allow(Search::Instrumentation).to receive(:evaluation_journey_recorded).and_raise(StandardError, 'private data')
    allow(Rails.logger).to receive(:warn)
    expect { described_class.record(**arguments) }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with('Could not capture classifier journey: StandardError')
  end

  %w[admin backend_only].each do |source|
    it "does not emit reporting traces for #{source}" do
      TradeTariffRequest.request_source = source
      described_class.record(**arguments)
      expect(Search::Instrumentation).not_to have_received(:evaluation_journey_recorded)
    end
  end

  it 'does not emit XI reporting traces' do
    allow(TradeTariffBackend).to receive(:uk?).and_return(false)
    described_class.record(**arguments)
    expect(Search::Instrumentation).not_to have_received(:evaluation_journey_recorded)
  end

  it 'does not emit a successful trace for degraded responses' do
    TradeTariffRequest.search_failures = %w[query_expansion_failed]
    described_class.record(**arguments)
    expect(Search::Instrumentation).not_to have_received(:evaluation_journey_recorded)
  end
end
