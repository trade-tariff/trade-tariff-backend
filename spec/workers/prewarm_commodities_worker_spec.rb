RSpec.describe PrewarmCommoditiesWorker do
  subject(:worker) { described_class.new }

  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
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
    allow(worker).to receive(:logger).and_return(logger)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('PREWARM_COMMODITY_IDS', '').and_return('')
  end

  describe '#perform' do
    it 'queries CloudWatch and prewarms cached commodities' do
      worker.perform

      expect(client).to have_received(:start_query)
      expect(CachedCommodityService).to have_received(:new).with(commodity, Date.current)
      expect(cached_commodity_service).to have_received(:call)
      expect(TimeMachine).to have_received(:now)
    end

    it 'builds the expected CloudWatch query payload' do
      now = Time.zone.parse('2026-04-21 10:00:00 UTC')
      allow(Time).to receive(:current).and_return(now, now)

      worker.perform

      expect(client).to have_received(:start_query).with(
        hash_including(
          log_group_name: PrewarmCommoditiesWorker::SEARCH_LOG_GROUP_NAME,
          start_time: (now - PrewarmCommoditiesWorker::DEFAULT_LOOKBACK_HOURS.hours).to_i,
          end_time: now.to_i,
          query_string: <<~QUERY,
            fields @timestamp, goods_nomenclature_item_id, event, service
            | filter service = "search" and event = "result_selected" and goods_nomenclature_class = "Commodity" and ispresent(goods_nomenclature_item_id)
            | stats count(*) as selections by goods_nomenclature_item_id
            | sort selections desc
            | limit #{PrewarmCommoditiesWorker::DEFAULT_LIMIT}
          QUERY
        ),
      )
    end

    it 'polls CloudWatch until query completes' do
      running_response = instance_double(
        Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
        status: 'Running',
        results: [],
      )
      allow(client).to receive(:get_query_results).and_return(running_response, query_results_response)
      allow(worker).to receive(:sleep)

      worker.perform

      expect(client).to have_received(:get_query_results).twice
      expect(worker).to have_received(:sleep).with(PrewarmCommoditiesWorker::QUERY_POLL_INTERVAL_SECONDS).once
    end

    it 'merges preconfigured ids with most requested ids' do
      allow(ENV).to receive(:fetch).with('PREWARM_COMMODITY_IDS', '').and_return("#{preconfigured_id},0101210000")

      worker.perform

      expect(Commodity).to have_received(:actual)
      expect(CachedCommodityService).to have_received(:new).with(preconfigured_commodity, Date.current)
      expect(CachedCommodityService).to have_received(:new).with(commodity, Date.current)
    end

    context 'when commodity list is empty' do
      let(:empty_query_results_response) do
        instance_double(
          Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
          status: 'Complete',
          results: [],
        )
      end

      before do
        allow(client).to receive_messages(start_query: start_query_response, get_query_results: empty_query_results_response)
      end

      it 'returns early when no ids are available from any source' do
        worker.perform

        expect(CachedCommodityService).not_to have_received(:new)
      end
    end

    context 'when CloudWatch query fails' do
      before do
        allow(client).to receive(:start_query).and_raise(StandardError, 'access denied')
      end

      it 'logs and continues with preconfigured ids' do
        allow(ENV).to receive(:fetch).with('PREWARM_COMMODITY_IDS', '').and_return(preconfigured_id)

        worker.perform

        expect(logger).to have_received(:error).with(/CloudWatch query failed/)
        expect(CachedCommodityService).to have_received(:new).with(preconfigured_commodity, Date.current)
      end
    end
  end
end
