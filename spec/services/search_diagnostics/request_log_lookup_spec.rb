RSpec.describe SearchDiagnostics::RequestLogLookup do
  subject(:lookup) do
    described_class.new(
      request_id:,
      lookback_hours:,
      limit:,
      client:,
      now:,
    )
  end

  let(:request_id) { 'request-123' }
  let(:lookback_hours) { nil }
  let(:limit) { nil }
  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:now) { Time.zone.parse('2026-06-05 10:00:00 UTC') }
  let(:start_query_response) { instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: 'query-123') }
  let(:query_results_response) do
    instance_double(
      Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
      status: 'Complete',
      results: [
        [
          result_field('@timestamp', '2026-06-05 09:59:00.000'),
          result_field('@message', {
            service: 'search',
            event: 'search_completed',
            request_id:,
            search_type: 'classic',
            query: 'horse',
            result_count: 3,
          }.to_json),
          result_field('event', 'search_completed'),
          result_field('request_id', request_id),
          result_field('search_type', 'classic'),
          result_field('result_count', '3'),
        ],
        [
          result_field('@timestamp', '2026-06-05 09:59:01.000'),
          result_field('@message', {
            service: 'search',
            event: 'search_completed',
            request_id:,
            search_type: 'interactive',
            query: 'horse',
            result_count: 1,
          }.to_json),
          result_field('event', 'search_completed'),
          result_field('request_id', request_id),
          result_field('search_type', 'interactive'),
          result_field('result_count', '1'),
        ],
      ],
    )
  end

  before do
    allow(client).to receive_messages(start_query: start_query_response, get_query_results: query_results_response)
  end

  describe '#call' do
    it 'queries the search log group for the request id' do
      lookup.call

      expect(client).to have_received(:start_query).with(
        hash_including(
          log_group_name: described_class::SEARCH_LOG_GROUP_NAME,
          start_time: (now - described_class::DEFAULT_LOOKBACK_HOURS.hours).to_i,
          end_time: now.to_i,
          query_string: a_string_including(
            'base_query',
            'effective_query',
            'added_answers',
            'iteration',
            'filter service = "search"',
            'request_id = "request-123"',
            "limit #{described_class::DEFAULT_LIMIT}",
          ),
        ),
      )
    end

    it 'returns structured log events' do
      result = lookup.call

      expect(result.request_id).to eq(request_id)
      expect(result.log_group_name).to eq(described_class::SEARCH_LOG_GROUP_NAME)
      expect(result.start_time).to eq('2026-06-02T10:00:00Z')
      expect(result.end_time).to eq('2026-06-05T10:00:00Z')
      expect(result.events.first.event).to eq('search_completed')
      expect(result.events.first.search_type).to eq('classic')
      expect(result.events.first.fields).to include(
        'query' => 'horse',
        'request_id' => request_id,
        'result_count' => '3',
      )
    end

    it 'returns classic and internal search events scoped by the same request id key' do
      events = lookup.call.events

      expect(events.map(&:search_type)).to eq(%w[classic interactive])
      expect(events.map { |event| event.fields['request_id'] }).to all(eq(request_id))
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
        lookup.call

        expect(client).to have_received(:get_query_results).twice
      end
    end

    context 'when CloudWatch reports a failed query' do
      let(:query_results_response) do
        instance_double(
          Aws::CloudWatchLogs::Types::GetQueryResultsResponse,
          status: 'Failed',
          results: [],
        )
      end

      it 'raises a query error' do
        expect { lookup.call }.to raise_error(described_class::QueryError, 'CloudWatch query Failed')
      end
    end

    context 'when polling raises a query error' do
      let(:query_error) { described_class::QueryError.new('CloudWatch query timed out while polling') }

      before do
        allow(client).to receive(:get_query_results).and_raise(query_error)
      end

      it 're-raises the original query error' do
        expect { lookup.call }.to raise_error(satisfy { |error| error.equal?(query_error) })
      end
    end

    context 'with bounded params' do
      let(:lookback_hours) { 999 }
      let(:limit) { 999 }

      it 'clamps the lookback and limit' do
        lookup.call

        expect(client).to have_received(:start_query).with(
          hash_including(
            start_time: (now - described_class::MAX_LOOKBACK_HOURS.hours).to_i,
            query_string: a_string_including("limit #{described_class::MAX_LIMIT}"),
          ),
        )
      end
    end

    context 'with a blank request id' do
      let(:request_id) { ' ' }

      it 'raises an argument error' do
        expect { lookup }.to raise_error(ArgumentError, 'request_id is required')
      end
    end
  end

  def result_field(field, value)
    instance_double(Aws::CloudWatchLogs::Types::ResultField, field:, value:)
  end
end
