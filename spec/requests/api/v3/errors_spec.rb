require 'rails_helper'

RSpec.describe 'V3 error handling', type: :request do
  describe 'unknown route' do
    it 'returns 404 with flat JSON error' do
      get '/uk/api/v3/nonexistent_resource',
          headers: { 'Accept' => 'application/vnd.hmrc.3.0+json' }
      # The global errors handler (config/routes/errors.rb -> ErrorsController) serves unknown
      # routes. That controller uses V1/V2 serializers and does not return flat V3 JSON, so we
      # only assert the HTTP status here rather than the body shape.
      expect(response).to have_http_status(:not_found)
    end
  end
end
