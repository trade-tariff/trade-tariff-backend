RSpec.describe Api::Admin::SearchAnalyticsController do
  describe 'GET #index' do
    let(:payload) do
      {
        'summary' => {
          'searches' => 1_240,
          'failure_rate' => 0.012,
          'zero_result_rate' => 0.084,
          'selection_rate' => 0.41,
          'p90_latency_ms' => 1_800,
        },
        'summary_statuses' => {
          'failure_rate' => {
            'level' => 'good',
            'message' => 'Failures are low',
          },
        },
        'trends' => {
          'volume' => [
            { 'bucket' => '2026-06-10T09:00:00Z', 'all' => 52, 'classic' => 31, 'internal' => 21 },
          ],
          'outcomes' => [],
        },
        'comparisons' => {
          'classic' => { 'searches' => 710 },
        },
        'improvement_terms' => [
          { 'query' => 'trainers', 'zero_results' => 18 },
        ],
      }
    end

    before do
      create(
        :search_analytics_snapshot,
        service: TradeTariffBackend.service,
        period: '24h',
        view: 'all',
        bucket_size: 'hour',
        generated_at: Time.zone.parse('2026-06-10 09:55:00 UTC'),
        data_through: Time.zone.parse('2026-06-10 09:50:00 UTC'),
        payload: payload,
      )
    end

    it 'returns the latest cached snapshot for the requested period and view' do
      get '/uk/admin/search_analytics.json',
          params: { period: '24h', view: 'all' },
          headers: request_headers(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include_json(
        data: {
          id: 'uk-24h-all',
          type: 'search_analytics',
          attributes: {
            service: 'uk',
            period: '24h',
            view: 'all',
            bucket_size: 'hour',
            generated_at: '2026-06-10T09:55:00Z',
            data_through: '2026-06-10T09:50:00Z',
            summary: {
              searches: 1_240,
              failure_rate: 0.012,
            },
            summary_statuses: {
              failure_rate: {
                level: 'good',
                message: 'Failures are low',
              },
            },
            trends: {
              volume: [
                {
                  bucket: '2026-06-10T09:00:00Z',
                  all: 52,
                  classic: 31,
                  internal: 21,
                },
              ],
            }.ignore_extra_keys!,
            comparisons: {
              classic: {
                searches: 710,
              },
            },
            improvement_terms: [
              {
                query: 'trainers',
                zero_results: 18,
              }.ignore_extra_keys!,
            ],
          }.ignore_extra_keys!,
        },
      )
    end

    it 'normalises unknown period and view values' do
      get '/uk/admin/search_analytics.json',
          params: { period: 'bad', view: 'bad' },
          headers: request_headers(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'id')).to eq('uk-24h-all')
    end

    it 'does not query CloudWatch from the request path' do
      allow(SearchAnalytics::CloudwatchQuery).to receive(:call)

      get '/uk/admin/search_analytics.json',
          params: { period: '24h', view: 'all' },
          headers: request_headers(format: :json)

      expect(SearchAnalytics::CloudwatchQuery).not_to have_received(:call)
    end

    context 'when no cached snapshot exists' do
      before do
        SearchAnalyticsSnapshot.dataset.delete
      end

      it 'returns a useful not found error' do
        get '/uk/admin/search_analytics.json',
            params: { period: '7d', view: 'classic' },
            headers: request_headers(format: :json)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body.fetch('errors').first).to include(
          'status' => '404',
          'title' => 'Search analytics unavailable',
          'detail' => 'No cached search analytics snapshot is available for 7d/classic',
        )
      end
    end
  end
end
