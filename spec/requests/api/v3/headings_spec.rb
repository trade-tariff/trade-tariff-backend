require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/headings', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'show' do
    before { create(:heading, :with_chapter, goods_nomenclature_item_id: '0101000000') }

    it 'returns 200 with flat heading object' do
      get '/uk/api/v3/headings/0101', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:goods_nomenclature_item_id]).to eq('0101000000')
    end

    it 'returns 404 when heading does not exist' do
      get '/uk/api/v3/headings/9999', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'commodities' do
    before { create(:heading, :with_chapter, :with_commodities, goods_nomenclature_item_id: '0101000000') }

    it 'returns 200 with commodities array' do
      get '/uk/api/v3/headings/0101/commodities', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end
end
