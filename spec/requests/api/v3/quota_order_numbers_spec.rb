require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/quota_order_numbers', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  context 'with quota order numbers in the database' do
    before { create(:quota_order_number) }

    it 'returns 200 with flat collection' do
      get '/uk/api/v3/quota_order_numbers', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body).to have_key(:data)
      expect(body).to have_key(:meta)
      expect(body[:data].first).to have_key(:quota_order_number_id)
    end
  end

  it 'returns 200 with empty collection when no records exist' do
    get '/uk/api/v3/quota_order_numbers', headers: headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body, symbolize_names: true)
    expect(body[:data]).to eq([])
  end
end
