RSpec.describe Api::Admin::CustomsTariffPipeline::EventsController do
  describe 'GET #index' do
    let!(:import_event) do
      create(:customs_tariff_pipeline_event,
             event_type: 'import',
             outcome: 'succeeded',
             customs_tariff_update_version: '1.1',
             occurred_at: Time.zone.local(2026, 6, 5, 10, 0, 0))
    end
    let!(:publish_event) do
      create(:customs_tariff_pipeline_event,
             event_type: 'publish',
             outcome: 'failed',
             customs_tariff_update_version: '1.2',
             occurred_at: Time.zone.local(2026, 6, 5, 11, 0, 0))
    end

    it 'returns pipeline events most recent first' do
      get '/uk/admin/customs_tariff_pipeline/events.json', headers: request_headers(format: :json)

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json['data'].map { |row| row.dig('attributes', 'event_type') }).to eq(%w[publish import])
      expect(json.dig('meta', 'pagination')).to include('page' => 1, 'total_count' => 2)
    end

    it 'filters by event type and time range' do
      get '/uk/admin/customs_tariff_pipeline/events.json',
          params: { event_type: 'import', from: '2026-06-05T09:30:00Z', to: '2026-06-05T10:30:00Z' },
          headers: request_headers(format: :json)

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json['data'].first.dig('attributes', 'customs_tariff_update_version')).to eq(import_event.customs_tariff_update_version)
    end

    it 'filters by outcome and source document version' do
      get '/uk/admin/customs_tariff_pipeline/events.json',
          params: { outcome: 'failed', customs_tariff_update_version: publish_event.customs_tariff_update_version },
          headers: request_headers(format: :json)

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json['data'].first.dig('attributes', 'event_type')).to eq('publish')
    end
  end
end
