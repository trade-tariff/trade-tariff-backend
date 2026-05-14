RSpec.describe Api::User::CommodityChangesController do
  include_context 'with user API authentication'

  let(:service_instance) { instance_double(Api::User::CommodityChangesService) }
  let(:grouped_change) do
    instance_double(
      TariffChanges::GroupedCommodityChange,
      id: 'ending',
      description: 'desc',
      count: 1,
      tariff_changes: [],
      tariff_change_ids: [],
    )
  end
  let(:changes) { [grouped_change] }
  let(:as_of) { '2025-11-24' }

  before do
    allow(Api::User::CommodityChangesService).to receive(:new).and_return(service_instance)
    allow(service_instance).to receive(:call).and_return(changes)
    allow(Api::User::CommodityChangesSerializer).to receive(:new).and_call_original
    allow(Api::User::UserService).to receive(:find_or_create).and_return(user)
  end

  describe '#index' do
    it 'authenticates the user and calls the service' do
      allow(Api::User::CommodityChangesService).to receive(:new).with(user, nil, anything).and_return(service_instance)
      allow(service_instance).to receive(:call).and_return(changes)
      get :index
      expect(Api::User::CommodityChangesService).to have_received(:new).with(user, nil, anything)
      expect(service_instance).to have_received(:call)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'as_of param' do
    it 'uses param if present' do
      allow(Api::User::CommodityChangesService).to receive(:new).with(user, nil, Date.parse(as_of)).and_return(service_instance)
      get :index, params: { as_of: }
      expect(Api::User::CommodityChangesService).to have_received(:new).with(user, nil, Date.parse(as_of))
      expect(response).to have_http_status(:ok)
    end

    it 'uses yesterday as date if param missing' do
      allow(Api::User::CommodityChangesService).to receive(:new).with(user, nil, Time.zone.yesterday).and_return(service_instance)
      get :index
      expect(Api::User::CommodityChangesService).to have_received(:new).with(user, nil, Time.zone.yesterday)
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#show' do
    before do
      allow(Api::User::CommodityChangesService).to receive(:new).and_return(service_instance)
      allow(service_instance).to receive(:call).and_return(changes)
      allow(Api::User::CommodityChangesSerializer).to receive(:new).and_call_original
    end

    it 'authenticates the user and calls the service with id' do
      allow(Api::User::CommodityChangesService).to receive(:new).with(user, '1', anything).and_return(service_instance)
      get :show, params: { id: '1' }
      expect(Api::User::CommodityChangesService).to have_received(:new).with(user, '1', anything)
      expect(service_instance).to have_received(:call)
      expect(Api::User::CommodityChangesSerializer).to have_received(:new).with(changes, anything)
      expect(response).to have_http_status(:ok)
    end

    it 'uses as_of param if present' do
      allow(Api::User::CommodityChangesService).to receive(:new).with(user, '2', Date.parse(as_of)).and_return(service_instance)
      get :show, params: { id: '2', as_of: }
      expect(Api::User::CommodityChangesService).to have_received(:new).with(user, '2', Date.parse(as_of))
      expect(response).to have_http_status(:ok)
    end
  end
end
