RSpec.describe Api::User::CommodityChangesController do
  routes { UserApi.routes }
  let(:user_token) { 'Bearer tariff-api-test-token' }
  let(:user_id) { 'user123' }
  let(:user) { create(:public_user, external_id: user_id) }
  let(:user_hash) { { 'sub' => user_id, 'email' => 'test@example.com' } }
  let(:service_instance) { instance_double(Api::User::CommodityChangesService) }
  let(:changes) { [OpenStruct.new(id: 'commodity_endings', description: 'desc', count: 1)] }

  before do
    request.headers['Authorization'] = user_token
    allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(user_hash)
    allow(Api::User::CommodityChangesService).to receive(:new).and_return(service_instance)
    allow(service_instance).to receive(:call).and_return(changes)
    allow(Api::User::CommodityChangeSerializer).to receive(:new).and_call_original
    allow(Api::User::UserService).to receive(:find_or_create).and_return(user)
  end

  describe '#index' do
    it 'authenticates the user and calls the service' do
      allow(Api::User::CommodityChangesService).to receive(:new).with(user, anything).and_return(service_instance)
      allow(service_instance).to receive(:call).and_return(changes)
      get :index
      expect(Api::User::CommodityChangesService).to have_received(:new).with(user, anything)
      expect(service_instance).to have_received(:call)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'as_of param' do
    it 'uses param if present' do
      allow(Api::User::CommodityChangesService).to receive(:new).with(user, '2025-11-24').and_return(service_instance)
      get :index, params: { as_of: '2025-11-24' }
      expect(Api::User::CommodityChangesService).to have_received(:new).with(user, '2025-11-24')
      expect(response).to have_http_status(:ok)
    end

    it 'uses yesterday as date if param missing' do
      allow(Api::User::CommodityChangesService).to receive(:new).with(user, Time.zone.yesterday.to_date.to_s).and_return(service_instance)
      get :index
      expect(Api::User::CommodityChangesService).to have_received(:new).with(user, Time.zone.yesterday.to_date.to_s)
      expect(response).to have_http_status(:ok)
    end
  end
end
