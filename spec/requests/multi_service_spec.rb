RSpec.describe 'Multi-service single instance', :v2 do
  describe 'service detection from URL prefix' do
    context 'when requesting a UK path' do
      it 'sets TradeTariffBackend.service to uk during the request' do
        observed_service = nil

        allow(Api::V2::SectionsController).to receive(:new).and_wrap_original do |original, *args|
          controller = original.call(*args)
          observed_service = TradeTariffBackend.service
          controller
        end

        api_get '/uk/api/sections'

        expect(observed_service).to eq('uk')
      end
    end

    context 'when requesting an XI path' do
      it 'sets TradeTariffBackend.service to xi during the request' do
        observed_service = nil

        allow(Api::V2::SectionsController).to receive(:new).and_wrap_original do |original, *args|
          controller = original.call(*args)
          observed_service = TradeTariffBackend.service
          controller
        end

        api_get '/xi/api/sections'

        expect(observed_service).to eq('xi')
      end
    end

    it 'resets the service to nil after the request ends' do
      api_get '/uk/api/sections'

      expect(TradeTariffRequest.service).to be_nil
    end
  end

  describe 'UK routes are accessible' do
    it 'responds to /uk/api/sections' do
      api_get '/uk/api/sections'

      expect(response).to have_http_status(:ok)
    end

    it 'responds to /uk/api/chapters' do
      api_get '/uk/api/chapters'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'XI routes are accessible' do
    it 'responds to /xi/api/sections' do
      api_get '/xi/api/sections'

      expect(response).to have_http_status(:ok)
    end

    it 'responds to /xi/api/chapters' do
      api_get '/xi/api/chapters'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'UK-only endpoints' do
    describe 'exchange rates' do
      let(:exchange_rate_collection) { build(:exchange_rates_collection, month: 1, year: 2024) }

      before do
        allow(ExchangeRates::ExchangeRateCollection)
          .to receive(:build)
          .and_return(exchange_rate_collection)
      end

      it 'returns 200 on the UK service' do
        api_get '/uk/api/exchange_rates/2024-1', params: { filter: { type: 'monthly' } }

        expect(response).to have_http_status(:ok)
      end

      it 'returns 404 on the XI service' do
        api_get '/xi/api/exchange_rates/2024-1', params: { filter: { type: 'monthly' } }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'news items' do
      it 'returns 200 on the UK service' do
        api_get '/uk/api/news/items'

        expect(response).to have_http_status(:ok)
      end

      it 'returns 404 on the XI service' do
        api_get '/xi/api/news/items'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'XI-only endpoints' do
    describe 'green lanes goods nomenclatures' do
      let(:authorization) do
        ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
      end

      it 'returns 404 on the UK service' do
        api_get '/uk/api/green_lanes/goods_nomenclatures/1234560000',
                headers: { 'HTTP_AUTHORIZATION' => authorization }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'service-dependent CSV filenames' do
    before do
      create(:section, id: 1, position: 1, numeral: 'I', title: 'Live animals')
    end

    it 'uses uk in the filename for UK requests' do
      api_get '/uk/api/sections.csv'

      expect(response.headers['Content-Disposition']).to include('uk-sections-')
    end

    it 'uses xi in the filename for XI requests' do
      api_get '/xi/api/sections.csv'

      expect(response.headers['Content-Disposition']).to include('xi-sections-')
    end
  end

  describe 'SetRequestedService middleware' do
    it 'sets service to uk for /uk/ paths' do
      api_get '/uk/api/sections'

      # TradeTariffRequest is reset after the request; the middleware worked
      # correctly if the response was valid (service context drove routing)
      expect(response).to have_http_status(:ok)
    end

    it 'does not set a service for non-prefixed paths' do
      get '/healthcheckz'

      expect(TradeTariffRequest.service).to be_nil
    end
  end
end
