require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/search', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }
  let(:search_service) { instance_double(SearchService, to_json: '{"results":[]}') }

  before do
    allow(SearchService).to receive(:new).and_return(search_service)
  end

  it 'returns 200 for a valid search query' do
    get '/uk/api/v3/search', params: { q: 'live animals' }, headers: headers
    expect(response).to have_http_status(:ok)
  end

  it 'returns 200 for an empty query' do
    get '/uk/api/v3/search', params: { q: '' }, headers: headers
    expect(response).to have_http_status(:ok)
  end
end
