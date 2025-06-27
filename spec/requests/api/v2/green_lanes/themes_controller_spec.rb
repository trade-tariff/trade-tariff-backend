RSpec.describe Api::V2::GreenLanes::ThemesController, :v2 do
  subject(:page_response) { make_request && response }

  before { allow(TradeTariffBackend).to receive(:service).and_return 'xi' }

  let(:theme) { create :green_lanes_theme }

  describe 'GET to #index' do
    let(:make_request) do
      get api_green_lanes_themes_path(format: :json),
          headers: { 'HTTP_AUTHORIZATION' => authorization }
    end

    let :authorization do
      ActionController::HttpAuthentication::Token.encode_credentials('Trade-Tariff-Test')
    end

    before do
      allow(TradeTariffBackend).to receive(:green_lanes_api_tokens).and_return 'Trade-Tariff-Test'
    end

    context 'when theme data is found' do
      it_behaves_like 'a successful jsonapi response'
    end

    context 'when request on uk service' do
      before do
        allow(TradeTariffBackend).to receive(:service).and_return 'uk'
      end

      it { is_expected.to have_http_status(:not_found) }
    end
  end
end
