RSpec.describe Search::ResultOffers do
  let(:items) do
    %w[possible strong good unlikely unknown good].each_with_index.map do |confidence, index|
      { attributes: { goods_nomenclature_item_id: "020714100#{index}", classification_description: 'Frozen cuts', confidence:, score: 1 } }
    end
  end
  let(:response) { { data: items, meta: { interactive_search: { result_limit: 5 } } } }

  before do
    TradeTariffRequest.request_source = 'frontend'
    allow(TradeTariffBackend).to receive(:uk?).and_return(true)
    allow(Search::Instrumentation).to receive(:result_offered)
  end

  after { TradeTariffRequest.reset }

  def record = described_class.record(response:, request_id: 'journey')

  it 'uses response order and the display limit' do
    record
    expect(Search::Instrumentation).to have_received(:result_offered).exactly(5).times
    expect(Search::Instrumentation).to have_received(:result_offered).with(request_id: 'journey', result_rank: 1, confidence: 'possible')
    expect(Search::Instrumentation).to have_received(:result_offered).with(request_id: 'journey', result_rank: 2, confidence: 'strong')
    expect(Search::Instrumentation).not_to have_received(:result_offered).with(hash_including(result_rank: 6))
  end

  it 'routes the page before limiting displayed results' do
    response[:data] = Array.new(5) { items.last.merge(attributes: items.last[:attributes].merge(confidence: 'unknown')) } + [items.first]
    record
    expect(Search::Instrumentation).to have_received(:result_offered).exactly(5).times
    expect(Search::Instrumentation).to have_received(:result_offered).with(request_id: 'journey', result_rank: 1, confidence: 'unknown')
  end

  it 'does not count backend error pages' do
    response[:meta][:interactive_search][:error] = 'Search failed'
    record
    expect(Search::Instrumentation).not_to have_received(:result_offered)
  end

  it 'keeps all results for a zero limit' do
    response[:meta][:interactive_search][:result_limit] = 0
    record
    expect(Search::Instrumentation).to have_received(:result_offered).exactly(6).times
  end

  it 'uses the frontend default limit' do
    response[:meta] = {}
    record
    expect(Search::Instrumentation).to have_received(:result_offered).exactly(5).times
  end

  it 'counts guided exact matches as offered' do
    response[:data] = [{ attributes: { goods_nomenclature_item_id: '0207141000', confidence: 'Strong', score: nil } }]
    record
    expect(Search::Instrumentation).to have_received(:result_offered).with(request_id: 'journey', result_rank: 1, confidence: 'strong')
  end

  it 'does not count pending question results' do
    response[:meta][:interactive_search][:answers] = [{ question: 'Cut?', options: %w[Whole Fillet], answer: nil }]
    record
    expect(Search::Instrumentation).not_to have_received(:result_offered)
  end

  it 'does not count blocking guidance results' do
    response[:meta][:description_intercept] = { excluded: true, message_header: 'Stop', message: 'Guidance' }
    record
    expect(Search::Instrumentation).not_to have_received(:result_offered)
  end

  it 'does not count unknown or empty pages' do
    response[:data] = [items.last.merge(attributes: items.last[:attributes].merge(confidence: 'unknown'))]
    record
    response[:data] = []
    record
    expect(Search::Instrumentation).not_to have_received(:result_offered)
  end

  it 'excludes non-frontend and XI responses' do
    TradeTariffRequest.request_source = 'admin'
    record
    TradeTariffRequest.request_source = 'frontend'
    allow(TradeTariffBackend).to receive(:uk?).and_return(false)
    record
    expect(Search::Instrumentation).not_to have_received(:result_offered)
  end

  it 'does not interrupt search on log failure' do
    allow(Search::Instrumentation).to receive(:result_offered).and_raise(StandardError, 'private input')
    allow(Rails.logger).to receive(:warn)
    expect { record }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with('Could not record result offers: StandardError')
  end
end
