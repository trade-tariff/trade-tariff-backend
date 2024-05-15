RSpec.describe Api::Admin::GreenLanes::ExemptionsController do
  subject(:page_response) { make_request && response }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(page_response.body) }
  let(:exemption) { create :green_lanes_exemption }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_exemptions_path(format: :json)
    end

    context 'with some exemptions' do
      before { exemption }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response['data'].first['type']).to include('green_lanes_exemption') }
    end

    context 'without any exemptions' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end
end
