require 'rails_helper'

RSpec.describe Api::Admin::CustomsTariffUpdatesController do
  describe 'GET #index' do
    before { create(:customs_tariff_update) }

    it 'returns paginated updates' do
      get '/uk/admin/customs_tariff_updates.json',
          params: { page: 1, per_page: 1 },
          headers: request_headers(format: :json)

      expect(response.status).to eq(200)
      response_body = JSON.parse(response.body)
      data = response_body['data']
      expect(data).to be_an(Array)
      expect(data.first['type']).to eq('customs_tariff_update')
      expect(data.first.dig('attributes', 'import_error')).to be_nil
      expect(response_body.dig('meta', 'pagination')).to include(
        'page' => 1,
        'per_page' => 1,
        'total_count' => 1,
      )
    end
  end

  describe 'GET #show' do
    let!(:update) { create(:customs_tariff_update) }

    it 'returns the update' do
      get "/uk/admin/customs_tariff_updates/#{update.version}", headers: request_headers(format: :json)

      expect(response.status).to eq(200)
      data = JSON.parse(response.body)['data']
      expect(data['type']).to eq('customs_tariff_update')
      expect(data.dig('attributes', 'version')).to eq(update.version)
      expect(data.dig('attributes', 'import_error')).to be_nil
    end

    it 'returns 404 for unknown version' do
      get '/uk/admin/customs_tariff_updates/does-not-exist.json', headers: request_headers(format: :json)

      expect(response.status).to eq(404)
    end
  end
end
