RSpec.describe 'Legacy API path redirects', type: :request do
  let(:docs_link) { '<https://docs.trade-tariff.service.gov.uk/reference.html>; rel="deprecation"' }

  describe 'GET /api/v2/... (no service prefix)' do
    it 'redirects to the UK service path with 308 and keeps the query string' do
      get '/api/v2/sections?foo=1'

      expect(response).to have_http_status(:permanent_redirect)
      expect(response.headers['Location']).to eq('/uk/api/v2/sections?foo=1')
    end

    it 'keeps the format extension' do
      get '/api/v2/changes.atom'

      expect(response.headers['Location']).to eq('/uk/api/v2/changes.atom')
    end

    it 'redirects to the XI service path when the backend is the XI service' do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')

      get '/api/v2/sections'

      expect(response.headers['Location']).to eq('/xi/api/v2/sections')
    end

    it 'sends the deprecation headers' do
      get '/api/v2/sections'

      expect(response.headers).to include(
        'Deprecation' => 'true',
        'Sunset' => LegacyApiRedirect::SUNSET_DATE.httpdate,
        'Link' => docs_link,
      )
    end
  end

  describe 'POST /api/v2/... (no service prefix)' do
    it 'redirects with 308 so the method and body are kept' do
      post '/api/v2/search', params: { q: 'horse' }

      expect(response).to have_http_status(:permanent_redirect)
      expect(response.headers['Location']).to eq('/uk/api/v2/search')
    end
  end

  describe 'paths that must not redirect' do
    it 'keeps returning 404 for the disabled v1 API' do
      get '/api/v1/sections'

      expect(response).to have_http_status(:not_found)
    end

    it 'serves /uk/api/v2/... without a redirect or deprecation headers' do
      get '/uk/api/v2/sections'

      expect(response).not_to have_http_status(:permanent_redirect)
      expect(response.headers).not_to include('Deprecation')
    end
  end
end
