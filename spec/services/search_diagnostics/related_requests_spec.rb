RSpec.describe SearchDiagnostics::RelatedRequests do
  let(:now) { Time.zone.parse('2026-06-05 10:00:00 UTC') }
  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:request_id) { '9b6ac6c9-55e2-442c-993b-c73274216ad0' }
  let(:other_request_id) { 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' }
  let(:browser_session_id) { "v1:#{'a' * 64}" }

  def result_field(field, value)
    instance_double(Aws::CloudWatchLogs::Types::ResultField, field:, value:)
  end

  def query_response(query_id)
    instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id:)
  end

  def results_response(rows)
    instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Complete', results: rows)
  end

  def message_row(timestamp, payload)
    [
      result_field('@timestamp', timestamp),
      result_field('@message', "I, [2026-06-05T10:00:00 #1] INFO -- : #{payload.to_json}"),
    ]
  end

  describe '.for_search_request' do
    before do
      session_rows = [
        message_row(
          '2026-06-05 09:59:00.000',
          {
            event: 'guided_search.journey',
            browser_session_id:,
            request_id:,
            experiment: 'hmrc-users',
          },
        ),
      ]
      related_rows = [
        message_row(
          '2026-06-05 09:58:00.000',
          {
            browser_session_id:,
            search_request_id: other_request_id,
            request_id: '11111111-2222-3333-4444-555555555555',
            params: { q: 'leather coat' },
          },
        ),
        message_row(
          '2026-06-05 09:59:30.000',
          {
            event: 'guided_search.journey',
            browser_session_id:,
            request_id:,
            experiment: 'hmrc-users',
          },
        ),
      ]
      allow(client).to receive(:start_query).and_return(query_response('session-query'), query_response('related-query'))
      allow(client).to receive(:get_query_results).with(query_id: 'session-query').and_return(results_response(session_rows))
      allow(client).to receive(:get_query_results).with(query_id: 'related-query').and_return(results_response(related_rows))
    end

    it 'returns the browser session and other search requests' do
      result = described_class.for_search_request(request_id:, client:, now:)

      expect(result.browser_session_id).to eq(browser_session_id)
      expect(result.experiment).to eq('hmrc-users')
      expect(result.requests.map(&:request_id)).to eq([other_request_id])
      expect(result.requests.first.query).to eq('leather coat')
    end

    it 'does not query when the request id is not a search uuid' do
      result = described_class.for_search_request(request_id: 'request-123', client:, now:)

      expect(result.requests).to be_empty
      expect(client).not_to have_received(:start_query)
    end
  end

  describe '.for_filter' do
    it 'returns search requests for an experiment label' do
      allow(client).to receive_messages(
        start_query: query_response('experiment-query'),
        get_query_results: results_response(
          [
            [
              result_field('@timestamp', '2026-06-05 09:40:00.000'),
              result_field('@message', { event: 'search_started', request_id:, query: 'fur coat', experiment: 'hmrc-users' }.to_json),
              result_field('request_id', request_id),
              result_field('query', 'fur coat'),
              result_field('experiment', 'hmrc-users'),
            ],
          ],
        ),
      )

      result = described_class.for_filter(experiment: 'hmrc-users', client:, now:)

      expect(result.requests.map(&:request_id)).to eq([request_id])
      expect(client).to have_received(:start_query).with(
        hash_including(query_string: a_string_including('event = "search_started"', 'experiment = "hmrc-users"')),
      )
    end

    it 'rejects an invalid browser session id' do
      expect { described_class.for_filter(browser_session_id: 'raw-session', client:, now:) }
        .to raise_error(ArgumentError, 'browser_session_id is invalid')
    end
  end
end
