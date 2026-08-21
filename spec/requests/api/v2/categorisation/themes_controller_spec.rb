RSpec.describe Api::V2::Categorisation::ThemesController, :v2 do
  subject(:api_response) do
    make_request
    response
  end

  before { allow(TradeTariffBackend).to receive(:service).and_return 'xi' }

  let(:theme) { create :green_lanes_theme }

  describe 'GET to #index' do
    let(:make_request) do
      api_get api_categorisation_themes_path(format: :json)
    end

    context 'when theme data is found' do
      it_behaves_like 'a successful jsonapi response'
    end

    context 'when no legacy API key/token is provided' do
      it 'does not require the green_lanes static API key/token' do
        expect(api_response).to have_http_status(:success)
      end
    end

    context 'when request on uk service' do
      before do
        allow(TradeTariffBackend).to receive(:service).and_return 'uk'
      end

      it { is_expected.to have_http_status(:not_found) }
    end
  end
end
