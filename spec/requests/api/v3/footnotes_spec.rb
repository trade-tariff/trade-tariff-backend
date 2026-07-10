require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/footnotes', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'footnotes index' do
    before { create(:footnote, :with_description) }

    it 'returns 200 with data array' do
      get '/uk/api/v3/footnotes', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end

  describe 'footnote_types index' do
    before { create(:footnote_type, :with_description) }

    it 'returns 200 with data array' do
      get '/uk/api/v3/footnote_types', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end
end
