require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/commodities', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'show' do
    before { create(:commodity, :with_chapter, :with_heading, goods_nomenclature_item_id: '0101210010') }

    it 'returns 200 with flat commodity object' do
      get '/uk/api/v3/commodities/0101210010', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:goods_nomenclature_item_id]).to eq('0101210010')
      expect(body[:declarable]).to be(true)
    end

    it 'returns 404 when commodity does not exist' do
      get '/uk/api/v3/commodities/9999999999', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'measures' do
    before { create(:commodity, :with_chapter, :with_heading, :with_measures, goods_nomenclature_item_id: '0101210010') }

    it 'returns 200 with measures split by trade direction' do
      get '/uk/api/v3/commodities/0101210010/measures', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:import_measures]).to be_an(Array)
      expect(body[:export_measures]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end
end
