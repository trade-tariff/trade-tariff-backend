RSpec.describe Api::Admin::GreenLanes::ExemptingCertificateOverridesController do
  subject(:page_response) { make_request && response }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(page_response.body) }
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
      it { is_expected.to have_attributes location: api_admin_green_lanes_exempting_certificate_override_url(GreenLanes::ExemptingCertificateOverride.last.id) }
      it { expect { page_response }.to change(GreenLanes::ExemptingCertificateOverride, :count).by(1) }
    end

    context 'with invalid params' do
      let(:eco_attrs) { build(:exempting_certificate_override, certificate_code: nil).to_hash }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for overrides' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(GreenLanes::ExemptingCertificateOverride, :count) }
    end
  end

  describe 'PATCH to #update' do
    let(:id) { override.id }
    let(:certificate_code) { '3' }

    let(:make_request) do
      authenticated_patch api_admin_green_lanes_exempting_certificate_override_path(id, format: :json), params: {
        data: {
          type: :exempting_certificate_override,
          attributes: { certificate_code: },
        },
      }
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { is_expected.to have_attributes location: api_admin_green_lanes_exempting_certificate_override_url(override.id) }
      it { expect { page_response }.not_to change(override.reload, :certificate_code) }
    end

    context 'with invalid params' do
      let(:certificate_code) { nil }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for category assessment' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(override.reload, :certificate_code) }
    end

    context 'with unknown category assessment' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(override.reload, :certificate_code) }
    end
  end

  describe 'DELETE to #destroy' do
    let :make_request do
      authenticated_delete api_admin_green_lanes_exempting_certificate_override_path(id, format: :json)
    end

    context 'with known category assessment' do
      let(:id) { override.id }

      it { is_expected.to have_http_status :no_content }
      it { expect { page_response }.to change(override, :exists?) }
    end

    context 'with unknown category assessment' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(GreenLanes::ExemptingCertificateOverride, :count) }
    end
  end
end
