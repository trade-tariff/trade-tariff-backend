RSpec.describe Api::Admin::CustomsTariffPipeline::MetricBinsController do
  describe 'GET #index' do
    before do
      create(:customs_tariff_pipeline_metric_bin,
             metric_name: 'import_runs',
             bucket_size: 'hour',
             bucket_start_at: Time.zone.local(2026, 6, 5, 9, 0, 0))
      create(:customs_tariff_pipeline_metric_bin,
             metric_name: 'review_backlog',
             bucket_size: 'hour',
             event_type: 'review',
             outcome: 'pending',
             count: 0,
             value_last: 12,
             bucket_start_at: Time.zone.local(2026, 6, 5, 10, 0, 0))
    end

    it 'returns metric bins earliest first' do
      get '/uk/admin/customs_tariff_pipeline/metric_bins.json', headers: request_headers(format: :json)

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json['data'].map { |row| row.dig('attributes', 'metric_name') }).to eq(%w[import_runs review_backlog])
    end

    it 'filters by metric name and bucket size' do
      get '/uk/admin/customs_tariff_pipeline/metric_bins.json',
          params: { metric_name: 'review_backlog', bucket_size: 'hour' },
          headers: request_headers(format: :json)

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json['data'].first.dig('attributes', 'value_last')).to eq(12)
    end
  end
end
