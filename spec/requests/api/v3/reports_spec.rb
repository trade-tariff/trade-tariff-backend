require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/reports', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  it 'returns 200 with empty data array' do
    get '/uk/api/v3/reports', headers: headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body, symbolize_names: true)
    expect(body[:data]).to eq([])
    expect(body[:meta][:total]).to eq(0)
  end
end
