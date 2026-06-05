RSpec.describe Api::Admin::SearchDiagnosticsController do
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
        ],
      )
    end

    before do
      allow(SearchDiagnostics::RequestLogLookup).to receive(:call).and_return(diagnostic)
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
