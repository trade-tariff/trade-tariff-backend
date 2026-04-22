RSpec.describe PrewarmCommoditiesWorker do
  subject(:worker) { described_class.new }

  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:start_query_response) { instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: 'query-123') }
  let(:query_results_response) do
    instance_double(
      Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
      status: 'Complete',
      results: [[
        instance_double(Aws::CloudWatchLogs::Types::ResultField, field: 'goods_nomenclature_item_id', value: '0101210000'),
        instance_double(Aws::CloudWatchLogs::Types::ResultField, field: 'selections', value: '42'),
      ]],
    )
  end
  let(:preconfigured_id) { '0202301000' }
  let(:commodity) { build(:commodity, goods_nomenclature_item_id: '0101210000', producline_suffix: '80') }
  let(:preconfigured_commodity) { build(:commodity, goods_nomenclature_item_id: preconfigured_id, producline_suffix: '80') }
  let(:query_scope) { instance_double(Sequel::Dataset, all: [commodity, preconfigured_commodity]) }
  let(:cached_commodity_service) { instance_double(CachedCommodityService, call: true) }

  before do
    allow(described_class).to receive(:client).and_return(client)
    allow(client).to receive_messages(start_query: start_query_response, get_query_results: query_results_response)
    allow(Commodity).to receive_message_chain(:actual, :by_codes).and_return(query_scope)
    allow(CachedCommodityService).to receive(:new).and_return(cached_commodity_service)
    allow(TimeMachine).to receive(:now).and_yield
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('PREWARM_COMMODITY_IDS', '').and_return('')
  end

  describe '#perform' do
    it 'queries CloudWatch and prewarms cached commodities' do
      worker.perform('search-log-group')

      expect(client).to have_received(:start_query)
      expect(CachedCommodityService).to have_received(:new).with(commodity, Date.current)
      expect(cached_commodity_service).to have_received(:call)
      expect(TimeMachine).to have_received(:now)
    end

    it 'merges preconfigured ids with most requested ids' do
      allow(ENV).to receive(:fetch).with('PREWARM_COMMODITY_IDS', '').and_return("#{preconfigured_id},0101210000")

      worker.perform('search-log-group')

      expect(Commodity).to have_received(:actual)
      expect(CachedCommodityService).to have_received(:new).with(preconfigured_commodity, Date.current)
      expect(CachedCommodityService).to have_received(:new).with(commodity, Date.current)
    end

    it 'returns early when both log group and preconfigured ids are missing' do
      worker.perform(nil)

      expect(client).not_to have_received(:start_query)
      expect(CachedCommodityService).not_to have_received(:new)
    end
  end
end
