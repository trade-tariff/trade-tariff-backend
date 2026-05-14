RSpec.describe Api::Admin::GreenLanes::ExemptingCertificateOverridesController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:override) { create :exempting_certificate_override }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_exempting_certificate_overrides_path(format: :json)
    end

    context 'with some overrides' do
      before do
        override
      end

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response).to include('meta') }
    end

    context 'without any overrides' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_exempting_certificate_override_path(id, format: :json)
    end

    context 'with existent override' do
      let(:id) { override.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'with non-existent overrides item' do
      let(:id) { 1001 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_admin_green_lanes_exempting_certificate_overrides_path(format: :json), params: eco_data
    end

    let :eco_data do
      {
        data: {
          type: :exempting_certificate_override,
          attributes: eco_attrs,
        },
      }
    end

    context 'with valid params' do
      let(:eco_attrs) { build(:exempting_certificate_override).to_hash }

      it { is_expected.to have_http_status :created }
      it { expect { api_response }.to change(GreenLanes::ExemptingCertificateOverride, :count).by(1) }
    end

    context 'with invalid params' do
      let(:eco_attrs) { build(:exempting_certificate_override, certificate_code: nil).to_hash }

      it { is_expected.to have_http_status :unprocessable_content }

      it 'returns errors for overrides' do
        expect(json_response).to include('errors')
      end

      it { expect { api_response }.not_to change(GreenLanes::ExemptingCertificateOverride, :count) }
    end
  end

  describe 'DELETE to #destroy' do
    let :make_request do
      authenticated_delete api_admin_green_lanes_exempting_certificate_override_path(id, format: :json)
    end

    context 'with known category assessment' do
      let(:id) { override.id }

      it { is_expected.to have_http_status :no_content }
      it { expect { api_response }.to change(override, :exists?) }
    end

    context 'with unknown category assessment' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { api_response }.not_to change(GreenLanes::ExemptingCertificateOverride, :count) }
    end
  end
end
