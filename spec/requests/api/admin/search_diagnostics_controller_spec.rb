RSpec.describe Api::Admin::SearchDiagnosticsController do
  describe 'GET #index' do
    let(:browser_session_id) { "v1:#{'b' * 64}" }
    let(:related_request) do
      SearchDiagnostics::RelatedRequests::Request.new(
        request_id: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        occurred_at: '2026-06-05 09:40:00.000',
        query: 'fur coat',
        experiment: 'hmrc-users',
        browser_session_id:,
      )
    end
    let(:correlation) do
      SearchDiagnostics::RelatedRequests::Result.new(
        browser_session_id:,
        experiment: nil,
        requests: [related_request],
      )
    end

    before do
      allow(SearchDiagnostics::RelatedRequests).to receive(:for_filter).and_return(correlation)
    end

    it 'returns clickable search requests for a browser session' do
      get '/uk/admin/search_diagnostics.json', params: { browser_session_id: }, headers: request_headers(format: :json)

      expect(response).to have_http_status(:ok)
      expect(SearchDiagnostics::RelatedRequests).to have_received(:for_filter).with(
        browser_session_id:,
        experiment: nil,
        lookback_hours: nil,
      )
      expect(response.parsed_body.dig('data', 0, 'id')).to eq(related_request.request_id)
      expect(response.parsed_body.dig('data', 0, 'attributes', 'query')).to eq('fur coat')
    end
  end

  describe 'GET #show' do
    let(:diagnostic) do
      SearchDiagnostics::RequestLogLookup::Result.new(
        request_id: 'request-123',
        log_group_name: 'platform-logs-test',
        start_time: '2026-06-02T10:00:00Z',
        end_time: '2026-06-05T10:00:00Z',
        events: [
          SearchDiagnostics::RequestLogLookup::Event.new(
            timestamp: '2026-06-05 09:59:00.000',
            event: 'search_completed',
            search_type: 'classic',
            message: '{"event":"search_completed"}',
            fields: {
              'event' => 'search_completed',
              'request_id' => 'request-123',
              'search_type' => 'classic',
              'query' => 'horse',
            },
          ),
          SearchDiagnostics::RequestLogLookup::Event.new(
            timestamp: '2026-06-05 09:59:01.000',
            event: 'note_evidence_evaluated',
            search_type: 'interactive',
            message: '{"event":"note_evidence_evaluated"}',
            fields: {
              'event' => 'note_evidence_evaluated',
              'request_id' => 'request-123',
              'search_type' => 'interactive',
              'note_evidence_status' => 'selected',
              'details' => {
                'selected_contexts' => [
                  {
                    'context_hash' => 'hash-1',
                    'note_ref' => 'compressed_note_1',
                    'evidence' => [{ 'source_node_key' => 'note_block:chapter:72:1:a' }],
                  },
                ],
              },
            },
          ),
        ],
      )
    end

    let(:correlation) do
      SearchDiagnostics::RelatedRequests::Result.new(
        browser_session_id: nil,
        experiment: nil,
        requests: [],
      )
    end

    before do
      allow(SearchDiagnostics::RequestLogLookup).to receive(:call).and_return(diagnostic)
      allow(SearchDiagnostics::RelatedRequests).to receive_messages(for_search_request: correlation, for_filter: correlation)
    end

    it 'returns nested note evidence diagnostics unchanged' do
      get '/uk/admin/search_diagnostics/request-123.json', headers: request_headers(format: :json)

      note_event = response.parsed_body.dig('data', 'attributes', 'events').find do |event|
        event['event'] == 'note_evidence_evaluated'
      end
      expect(note_event['fields']).to include(
        'note_evidence_status' => 'selected',
        'details' => {
          'selected_contexts' => [
            {
              'context_hash' => 'hash-1',
              'note_ref' => 'compressed_note_1',
              'evidence' => [{ 'source_node_key' => 'note_block:chapter:72:1:a' }],
            },
          ],
        },
      )
    end

    it 'returns search diagnostics for the request id' do
      get '/uk/admin/search_diagnostics/request-123.json',
          params: { lookback_hours: 24, limit: 50 },
          headers: request_headers(format: :json)

      expect(response).to have_http_status(:ok)
      expect(SearchDiagnostics::RequestLogLookup).to have_received(:call).with(
        request_id: 'request-123',
        lookback_hours: '24',
        limit: '50',
      )
      expect(response.parsed_body).to include_json(
        data: {
          id: 'request-123',
          type: 'search_diagnostic',
          attributes: {
            request_id: 'request-123',
            log_group_name: 'platform-logs-test',
            events: [
              {
                event: 'search_completed',
                search_type: 'classic',
                fields: {
                  request_id: 'request-123',
                  query: 'horse',
                },
              },
            ],
          }.ignore_extra_keys!,
        },
      )
    end

    [SearchDiagnostics::RequestLogLookup::QueryError, Aws::Errors::ServiceError].each do |error_class|
      context "when correlation raises #{error_class}" do
        before do
          error = error_class == Aws::Errors::ServiceError ? error_class.new(nil, 'Unavailable') : error_class.new('Unavailable')
          allow(SearchDiagnostics::RelatedRequests).to receive(:for_search_request).and_raise(error)
        end

        it 'keeps the original diagnostics and marks related requests unavailable' do
          get '/uk/admin/search_diagnostics/request-123.json', headers: request_headers(format: :json)

          expect(response).to have_http_status(:ok)
          attributes = response.parsed_body.dig('data', 'attributes')
          expect(attributes).to include('related_requests_available' => false, 'related_requests' => [])
          expect(attributes['events'].first['event']).to eq('search_completed')
        end
      end
    end

    context 'when CloudWatch query fails' do
      before do
        allow(SearchDiagnostics::RequestLogLookup).to receive(:call).and_raise(
          SearchDiagnostics::RequestLogLookup::QueryError,
          'CloudWatch query Failed',
        )
      end

      it 'returns a bad gateway error' do
        get '/uk/admin/search_diagnostics/request-123.json', headers: request_headers(format: :json)

        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body['errors'].first).to include(
          'status' => '502',
          'detail' => 'CloudWatch query Failed',
        )
      end
    end
  end
end
