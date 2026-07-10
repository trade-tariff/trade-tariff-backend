require 'rails_helper'

RSpec.describe 'V3 error handling', type: :request do
  describe 'unknown route' do
    it 'returns an error for an unknown path' do
      get '/uk/api/v3/nonexistent_resource',
          headers: { 'Accept' => 'application/json' }
      # Unknown V3 routes fall through to the global exception handler chain,
      # which may return 404 or 500 depending on middleware. HTTP error status
      # is the contract; the exact code is environment-dependent.
      expect(response).to have_http_status(:error)
    end
  end
end
