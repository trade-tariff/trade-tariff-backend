require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/certificates', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  describe 'certificates index' do
    before { create(:certificate, :with_description) }

    it 'returns 200 with data array' do
      get '/uk/api/v3/certificates', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end

  describe 'certificate_types index' do
    before { create(:certificate_type, :with_description) }

    it 'returns 200 with data array' do
      get '/uk/api/v3/certificate_types', headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data]).to be_an(Array)
      expect(body[:meta][:total]).to be_an(Integer)
    end
  end
end
