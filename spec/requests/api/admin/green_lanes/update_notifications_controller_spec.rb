RSpec.describe Api::Admin::GreenLanes::UpdateNotificationsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:update) { create :update_notification }

  describe 'GET to #index' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_update_notifications_path(format: :json)
    end

    context 'with some update_notification' do
      before { update }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
      it { expect(json_response['data'].first['type']).to include('green_lanes_update_notification') }
    end

    context 'without any update_notification' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data' => []) }
    end
  end

  describe 'GET to #show' do
    let(:make_request) do
      authenticated_get api_admin_green_lanes_update_notification_path(id, format: :json)
    end

    context 'with existent update notification' do
      let(:id) { update.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to include('data') }
    end

    context 'with non-existent update notification' do
      let(:id) { 1001 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'PATCH to #update' do
    let(:id) { update.id }

    let(:make_request) do
      authenticated_patch api_admin_green_lanes_update_notification_path(id, format: :json)
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :success }
      it { expect { api_response }.not_to change(update.reload, :status) }
    end

    context 'with unknown update notification' do
      let(:id) { 9999 }

      it { is_expected.to have_http_status :not_found }
      it { expect { api_response }.not_to change(update.reload, :status) }
    end
  end
end
