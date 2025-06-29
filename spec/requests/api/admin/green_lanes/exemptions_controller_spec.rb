RSpec.describe Api::Admin::GreenLanes::ExemptionsController, :admin do
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

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_exemption_path(id, format: :json)
    end

    context 'with existent exemption' do
      let(:id) { exemption.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'with non-existent exemption' do
      let(:id) { 1001 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST to #create' do
    let(:make_request) do
      authenticated_post api_admin_green_lanes_exemptions_path(format: :json), params: exemption_data
    end

    let :exemption_data do
      {
        data: {
          type: :green_lanes_exemption,
          attributes: ex_attrs,
        },
      }
    end

    context 'with valid params' do
      let(:ex_attrs) { build(:green_lanes_exemption).to_hash }

      it { is_expected.to have_http_status :created }
      it { is_expected.to have_attributes location: api_admin_green_lanes_exemption_url(GreenLanes::Exemption.last.id) }
      it { expect { page_response }.to change(GreenLanes::Exemption, :count).by(1) }
    end

    context 'with invalid params' do
      let(:ex_attrs) { build(:green_lanes_exemption, code: nil).to_hash }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for exemption' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(GreenLanes::Exemption, :count) }
    end
  end

  describe 'PATCH to #update' do
    let(:id) { exemption.id }
    let(:updated_description) { 'new description' }

    let(:make_request) do
      authenticated_patch api_admin_green_lanes_exemption_path(id, format: :json), params: {
        data: {
          type: :green_lanes_exemption,
          attributes: { description: updated_description },
        },
      }
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { is_expected.to have_attributes location: api_admin_green_lanes_exemption_url(exemption.id) }
      it { expect { page_response }.not_to change(exemption.reload, :description) }
    end

    context 'with invalid params' do
      let(:updated_description) { nil }

      it { is_expected.to have_http_status :unprocessable_entity }

      it 'returns errors for exemption' do
        expect(json_response).to include('errors')
      end

      it { expect { page_response }.not_to change(exemption.reload, :description) }
    end

    context 'with unknown exemption' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(exemption.reload, :description) }
    end
  end

  describe 'DELETE to #destroy' do
    let :make_request do
      authenticated_delete api_admin_green_lanes_exemption_path(id, format: :json)
    end

    context 'with known exemption' do
      let(:id) { exemption.id }

      it { is_expected.to have_http_status :no_content }
      it { expect { page_response }.to change(exemption, :exists?) }
    end

    context 'with unknown exemption' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { page_response }.not_to change(GreenLanes::Exemption, :count) }
    end
  end
end
