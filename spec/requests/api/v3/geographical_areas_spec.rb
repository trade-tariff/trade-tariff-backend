require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/geographical_areas', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'index' do
    before { create(:geographical_area, :with_description, geographical_area_id: 'GB') }

    it 'returns 200 with flat collection' do
      get '/uk/api/v3/geographical_areas', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body).to have_key(:data)
      expect(body).to have_key(:meta)
      expect(body[:data].first[:geographical_area_id]).to eq('GB')
    end
  end

  describe 'show' do
    before { create(:geographical_area, :with_description, geographical_area_id: 'GB') }

    it 'returns 200 with flat area object' do
      get '/uk/api/v3/geographical_areas/GB', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:geographical_area_id]).to eq('GB')
    end

    it 'returns 404 when area does not exist' do
      get '/uk/api/v3/geographical_areas/ZZ', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
