RSpec.describe Api::Admin::CustomsTariffPipeline::AlertsController do
  describe 'GET #index' do
    before do
      create(:customs_tariff_pipeline_alert,
             alert_type: 'failed_import',
             severity: 'critical',
             status: 'open',
             triggered_at: Time.zone.local(2026, 6, 5, 10, 0, 0))
      create(:customs_tariff_pipeline_alert,
             alert_type: 'review_backlog_growth',
             severity: 'warning',
             status: 'resolved',
             triggered_at: Time.zone.local(2026, 6, 5, 9, 0, 0))
    end

    it 'returns alerts most recent first' do
      get '/uk/admin/customs_tariff_pipeline/alerts.json', headers: request_headers(format: :json)

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json['data'].map { |row| row.dig('attributes', 'alert_type') }).to eq(%w[failed_import review_backlog_growth])
    end

    it 'filters open critical alerts' do
      get '/uk/admin/customs_tariff_pipeline/alerts.json',
          params: { status: 'open', severity: 'critical' },
          headers: request_headers(format: :json)

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json['data'].first.dig('attributes', 'alert_type')).to eq('failed_import')
    end
  end
end
