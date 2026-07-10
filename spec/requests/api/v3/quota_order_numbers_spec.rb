require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/quota_order_numbers', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  it 'returns 200' do
    get '/uk/api/v3/quota_order_numbers', headers: headers
    expect(response).to have_http_status(:ok)
  end
end
