require 'rails_helper'

RSpec.describe 'get a 404 response (in JSON) from unmatched route', type: :request do
  it 'when the request is for HTML' do
    get '/foo'
    expect(response.body).to eq('{"error":"404 - Not Found"}')
    expect(response).to have_http_status(:not_found)
  end

  it 'when the request is for CSV' do
    get '/foo', headers: { "Content-Type": 'text/csv' }
    expect(response.body).to eq('{"error":"404 - Not Found"}')
    expect(response).to have_http_status(:not_found)
  end

  it 'when the request is for JSON' do
    get '/foo', headers: { "Content-Type": 'application/vnd.uktt.v2' }
    expect(response.body).to eq('{"error":"404 - Not Found"}')
    expect(response).to have_http_status(:not_found)
  end
end
