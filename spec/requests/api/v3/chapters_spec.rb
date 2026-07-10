require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/chapters', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'show' do
    before { create(:chapter, :with_section, goods_nomenclature_item_id: '0100000000') }

    it 'returns 200 with flat chapter object' do
      get '/uk/api/v3/chapters/01', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:goods_nomenclature_item_id]).to eq('0100000000')
    end

    it 'returns 404 when chapter does not exist' do
      get '/uk/api/v3/chapters/99', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'headings' do
    before { create(:chapter, :with_section, :with_headings, goods_nomenclature_item_id: '0100000000') }

    it 'returns 200 with headings array' do
      get '/uk/api/v3/chapters/01/headings', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end
end
