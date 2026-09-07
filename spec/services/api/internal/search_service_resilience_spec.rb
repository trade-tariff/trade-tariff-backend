RSpec.describe Api::Internal::SearchService do
  let(:request_id) { 'search-resilience-request' }
  let(:candidates) do
    (1..2).map do |sid|
      GoodsNomenclatureResult.new(
        id: sid, goods_nomenclature_sid: sid, goods_nomenclature_item_id: "420221000#{sid}",
        producline_suffix: '80', goods_nomenclature_class: 'Commodity',
        description: 'Handbag', formatted_description: 'Handbag', full_description: 'Handbag',
        classification_description: 'Handbag', heading_description: nil, self_text: nil,
        declarable: true, score: 10.0, confidence: nil
      )
    end
  end

  before do
    allow(AdminConfiguration).to receive(:option_value).and_call_original
    allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('opensearch')
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('interactive_search_enabled').and_return(true)
    allow(AdminConfiguration).to receive(:enabled?).with('search_compressed_notes_enabled').and_return(false)
    allow(OpensearchRetrievalService).to receive(:call).and_return(
      OpensearchRetrievalService::Result.new(results: candidates, expanded_query: 'handbag'),
    )
    allow(OpenaiClient).to receive(:call).and_raise(Faraday::TimeoutError, 'provider unavailable')
  end

  after { TradeTariffRequest.reset }

  it 'emits one outcome for a fallback', :aggregate_failures do
    events = []
    callback = ->(event) { events << event }
    response = ActiveSupport::Notifications.subscribed(callback, /\.search\z/) do
      described_class.new(q: 'handbag', expanded_query: 'handbag', request_id:, search_type: 'evaluation').call
    end

    expect(response[:data].size).to eq(2)
    expect(response.dig(:meta, :search_failures)).to eq(%w[interactive_search_failed])
    expect(events.map(&:name).grep(/search_(completed|failed)\.search/)).to eq(['search_completed.search'])
    expect(events.find { |event| event.name == 'search_stage_failed.search' }&.payload).to include(
      failure_code: 'interactive_search_failed', error_type: 'Faraday::TimeoutError', search_type: 'evaluation',
    )
  end

  it 'rejects malformed expansion safely', :aggregate_failures do
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(true)
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(false)
    allow(OpensearchRetrievalService).to receive(:call).and_call_original
    allow(TradeTariffBackend.search_client).to receive(:search).and_return('hits' => { 'hits' => [] })
    allow(OpenaiClient).to receive(:call).and_return('expanded_query' => 123)

    response = described_class.new(q: 'handbag', request_id:).call

    expect(response[:data]).to eq([])
    expect(response.dig(:meta, :search_failures)).to eq(%w[query_expansion_failed])
  end
end
