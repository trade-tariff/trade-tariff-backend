require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/subheadings', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'show' do
    before { create(:subheading, :with_description, goods_nomenclature_item_id: '0101210000') }

    it 'returns 200 with flat subheading object' do
      get '/uk/api/v3/subheadings/0101210000', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:goods_nomenclature_item_id]).to eq('0101210000')
      expect(body[:declarable]).to be(false)
    end

    it 'returns 404 when subheading does not exist' do
      get '/uk/api/v3/subheadings/9999999999', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'commodities' do
    before { create(:subheading, :with_description, :with_commodities, goods_nomenclature_item_id: '0101210000') }

    it 'returns 200 with commodities array' do
      get '/uk/api/v3/subheadings/0101210000/commodities', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end
end
