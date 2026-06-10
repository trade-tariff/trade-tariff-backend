RSpec.describe SearchAnalytics::CloudwatchQuery do
  subject(:query) do
    described_class.new(
      period: '24h',
      view: 'all',
      client: client,
      now: now,
    )
  end

  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:now) { Time.zone.parse('2026-06-10 10:00:00 UTC') }
  let(:start_query_response) { instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: 'query-123') }
  let(:query_results_response) do
    instance_double(
      Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
      status: 'Complete',
      results: [
        [
          result_field('@timestamp', '2026-06-10 09:59:00.000'),
          result_field('@message', {
            service: 'search',
            event: 'search_completed',
            search_type: 'classic',
            query: 'trainers',
            result_count: 3,
          }.to_json),
          result_field('event', 'search_completed'),
          result_field('search_type', 'classic'),
          result_field('result_count', '3'),
        ],
      ],
    )
  end

  before do
    allow(client).to receive_messages(start_query: start_query_response, get_query_results: query_results_response)
  end

  describe '#call' do
    it 'queries the platform search log group for the selected period window' do
      query.call

      expect(client).to have_received(:start_query).with(
        hash_including(
          log_group_name: "platform-logs-#{TradeTariffBackend.environment}",
          limit: 10_000,
          start_time: (now - 24.hours).to_i,
          end_time: now.to_i,
          query_string: a_string_including(
            'filter service = "search"',
            'search_completed',
            'result_selected',
          ),
        ),
      )
      expect(client).to have_received(:start_query).with(
        hash_including(query_string: satisfy { |query_string| !query_string.include?('suggestions_completed') }),
      )
    end

    it 'returns parsed row hashes' do
      rows = query.call

      expect(rows).to contain_exactly(
        include(
          '@timestamp' => '2026-06-10 09:59:00.000',
          'event' => 'search_completed',
          'search_type' => 'classic',
          'query' => 'trainers',
          'result_count' => '3',
        ),
      )
    end

    context 'when CloudWatch returns the maximum raw result count' do
      let(:query_results_response) do
        instance_double(
          Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
          status: 'Complete',
          results: Array.new(10_000) { [result_field('event', 'search_completed')] },
        )
      end

      it 'raises rather than building a misleading partial snapshot' do
        expect { query.call }.to raise_error(
          described_class::QueryError,
          'CloudWatch query reached the raw result limit; use an aggregated query for this period',
        )
      end
    end

    context 'when CloudWatch is still running the query' do
      let(:running_response) do
        instance_double(
          Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
          status: 'Running',
          results: [],
        )
      end

      before do
        allow(Kernel).to receive(:sleep)
        allow(client).to receive(:get_query_results).and_return(running_response, query_results_response)
      end

      it 'polls until the query completes' do
        query.call

        expect(client).to have_received(:get_query_results).twice
      end
    end

    %w[Failed Cancelled Timeout].each do |status|
      context "when CloudWatch reports #{status}" do
        let(:query_results_response) do
          instance_double(
            Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
            status: status,
            results: [],
          )
        end

        it 'raises a query error' do
          expect { query.call }.to raise_error(described_class::QueryError, "CloudWatch query #{status}")
        end
      end
    end

    context 'when CloudWatch does not complete within the poll limit' do
      let(:query_results_response) do
        instance_double(
          Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
          status: 'Running',
          results: [],
        )
      end

      before do
        stub_const("#{described_class}::QUERY_MAX_POLLS", 2)
        allow(Kernel).to receive(:sleep)
      end

      it 'raises a query error' do
        expect { query.call }.to raise_error(described_class::QueryError, 'CloudWatch query timed out while polling')
        expect(client).to have_received(:get_query_results).twice
      end
    end
  end

  def result_field(field, value)
    instance_double(Aws::CloudWatchLogs::Types::ResultField, field: field, value: value)
  end
end
