require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/sections', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'index' do
    before { create(:section, position: 1, numeral: 'I', title: 'Live Animals') }

    it 'returns 200 with flat data array' do
      get '/uk/api/v3/sections', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to eq(1)
      section = body[:data].first
      expect(section[:id]).to be_an(Integer)
      expect(section[:numeral]).to eq('I')
      expect(section[:title]).to eq('Live Animals')
    end
  end

  describe 'show' do
    before { create(:section, position: 1, numeral: 'I', title: 'Live Animals') }

    it 'returns 200 with flat section object' do
      get '/uk/api/v3/sections/1', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:id]).to eq(1)
      expect(body[:numeral]).to eq('I')
    end

    it 'returns 404 when section does not exist' do
      get '/uk/api/v3/sections/999', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'chapters' do
    before { create(:section, :with_chapter, position: 1) }

    it 'returns 200 with chapters array' do
      get '/uk/api/v3/sections/1/chapters', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end
end
