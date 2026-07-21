RSpec.describe PrewarmCommoditiesWorker do
  subject(:worker) { described_class.new }

  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:cached_commodity_service) { instance_double(CachedCommodityService, call: true) }

  def start_query_response
    instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: 'query-123')
  end

  def query_results_response
    instance_double(
      Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
      status: 'Complete',
      results: [[
        instance_double(Aws::CloudWatchLogs::Types::ResultField, field: 'goods_nomenclature_item_id', value: '0101210000'),
        instance_double(Aws::CloudWatchLogs::Types::ResultField, field: 'selections', value: '42'),
      ]],
    )
  end

  before do
    commodities = [
      build(:commodity, goods_nomenclature_item_id: '0101210000', producline_suffix: '80'),
      build(:commodity, goods_nomenclature_item_id: '0202301000', producline_suffix: '80'),
    ]
    query_scope = instance_double(Sequel::Dataset, all: commodities)
    # Commodity.actual returns a model dataset (Sequel::Dataset subclass with
    # by_codes), not bare Sequel::Dataset.
    actual_commodities = instance_double(Commodity.dataset.class, by_codes: query_scope)

    allow(described_class).to receive(:client).and_return(client)
    allow(client).to receive_messages(start_query: start_query_response, get_query_results: query_results_response)
    allow(Commodity).to receive(:actual).and_return(actual_commodities)
    allow(CachedCommodityService).to receive(:new).and_return(cached_commodity_service)
    allow(TimeMachine).to receive(:now).and_yield
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('PREWARM_COMMODITY_IDS', '').and_return('')
  end

  describe '#perform' do
    it 'queries CloudWatch and prewarms cached commodities' do
      worker.perform

      expect(client).to have_received(:start_query)
      expect(CachedCommodityService).to have_received(:new).with(
        an_object_having_attributes(goods_nomenclature_item_id: '0101210000'),
        Date.current,
      )
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

      worker.perform

      expect(client).to have_received(:get_query_results).twice
    end

    it 'merges preconfigured ids with most requested ids' do
      allow(ENV).to receive(:fetch).with('PREWARM_COMMODITY_IDS', '').and_return('0202301000,0101210000')

      worker.perform

      expect(Commodity).to have_received(:actual)
      expect(CachedCommodityService).to have_received(:new).with(
        an_object_having_attributes(goods_nomenclature_item_id: '0202301000'),
        Date.current,
      )
      expect(CachedCommodityService).to have_received(:new).with(
        an_object_having_attributes(goods_nomenclature_item_id: '0101210000'),
        Date.current,
      )
    end

    context 'when commodity list is empty' do
      before do
        empty_query_results_response = instance_double(
          Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
          status: 'Complete',
          results: [],
        )
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
        allow(ENV).to receive(:fetch).with('PREWARM_COMMODITY_IDS', '').and_return('0202301000')

        original_logger = Sidekiq.default_configuration.logger
        Sidekiq.default_configuration.logger = Logger.new(StringIO.new)
        begin
          worker.perform
        ensure
          Sidekiq.default_configuration.logger = original_logger
        end

        expect(CachedCommodityService).to have_received(:new).with(
          an_object_having_attributes(goods_nomenclature_item_id: '0202301000'),
          Date.current,
        )
      end
    end
  end
end
