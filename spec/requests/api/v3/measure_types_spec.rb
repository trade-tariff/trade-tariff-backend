require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/measure_types', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'index' do
    before { create(:measure_type) }

    it 'returns 200 with data array' do
      get '/uk/api/v3/measure_types', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end

  describe 'show' do
    before { create(:measure_type, measure_type_id: '103') }

    it 'returns 200 with flat measure type object' do
      get '/uk/api/v3/measure_types/103', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:id]).to eq('103')
    end

    it 'returns 404 when not found' do
      get '/uk/api/v3/measure_types/ZZZ', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
