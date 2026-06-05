RSpec.describe Api::Admin::CustomsTariffPipeline::DashboardController do
  describe 'GET #show' do
    before do
      create(:customs_tariff_pipeline_event,
             event_type: 'import',
             outcome: 'succeeded',
             occurred_at: Time.zone.local(2026, 6, 5, 9, 0, 0))
      create(:customs_tariff_pipeline_event,
             event_type: 'publish',
             outcome: 'failed',
             occurred_at: Time.zone.local(2026, 6, 5, 10, 0, 0))
      create(:customs_tariff_pipeline_metric_bin,
             metric_name: 'review_backlog',
             bucket_size: 'hour',
             count: 0,
             value_last: 7,
             bucket_start_at: Time.zone.local(2026, 6, 5, 10, 0, 0))
      create(:customs_tariff_pipeline_metric_bin,
             metric_name: 'import_runs',
             bucket_size: 'hour',
             bucket_start_at: Time.zone.local(2026, 6, 5, 10, 0, 0))
      create(:customs_tariff_pipeline_alert,
             alert_type: 'failed_publication',
             status: 'open',
             triggered_at: Time.zone.local(2026, 6, 5, 10, 5, 0))
    end

    it 'returns the dashboard summary' do
      get '/uk/admin/customs_tariff_pipeline/dashboard.json',
          params: { bucket_size: 'hour', from: '2026-06-05T08:00:00Z', to: '2026-06-05T11:00:00Z' },
          headers: request_headers(format: :json)

      json = JSON.parse(response.body)
      attributes = json.dig('data', 'attributes')

      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'type')).to eq('customs_tariff_pipeline_dashboard')
      expect(attributes.dig('latest_import_event', 'outcome')).to eq('succeeded')
      expect(attributes.dig('latest_publication_event', 'outcome')).to eq('failed')
      expect(attributes.dig('review_backlog', 'value_last')).to eq(7)
      expect(attributes['open_alerts_count']).to eq(1)
      expect(attributes['metric_bins'].length).to eq(2)
    end
  end
end
