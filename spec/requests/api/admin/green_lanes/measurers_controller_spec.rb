RSpec.describe Api::Admin::GreenLanes::MeasuresController do
  subject(:page_response) { make_request && response }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(page_response.body) }
  let(:measure) { create :green_lanes_measure }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_measures_path(format: :json)
    end

    context 'with some measures' do
      before { measure }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response['data'].first['type']).to include('green_lanes_measure') }
    end

    context 'without any measures' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end
end
