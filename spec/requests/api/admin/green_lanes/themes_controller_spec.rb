RSpec.describe Api::Admin::GreenLanes::ThemesController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:theme) { create :green_lanes_theme }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_themes_path(format: :json)
    end

    context 'with some themes' do
      before { theme }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'without any theme' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end
end
