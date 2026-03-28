RSpec.describe Api::User::DataExportController do
  include_context 'with user API authentication'

  let(:subscription) { create(:user_subscription, user: user, subscription_type: Subscriptions::Type.my_commodities) }
  let(:valid_subscription_id) { subscription.uuid }

  describe 'POST #create' do
    let(:params) do
      {
        subscription_id: valid_subscription_id,
        data: {
          attributes: {
            export_type: PublicUsers::DataExport::CCWL,
          },
        },
      }
    end

    before do
      allow(DataExportWorker).to receive(:perform_async)
    end

    it 'creates a queued data export and enqueues worker' do
      expect {
        post :create, params: params
      }.to change(PublicUsers::DataExport, :count).by(1)

      export = PublicUsers::DataExport.order(:id).last

      expect(response).to have_http_status(:accepted)
      expect(export.user_id).to eq(user.id)
      expect(export.export_type).to eq(PublicUsers::DataExport::CCWL)
      expect(export.status).to eq(PublicUsers::DataExport::QUEUED)
      expect(export.exporter_args).to eq({ 'subscription_id' => valid_subscription_id })
      expect(DataExportWorker).to have_received(:perform_async).with(export.id)
    end

    context 'when subscription is missing' do
      it 'returns unauthorized' do
        post :create, params: params.merge(subscription_id: SecureRandom.uuid)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when no auth token provided' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = nil
        post :create, params: params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    let(:data_export) do
      create(
        :data_export,
        user: user,
        export_type: PublicUsers::DataExport::CCWL,
        status: PublicUsers::DataExport::PROCESSING,
      )
    end

    it 'returns a successful response for matching user + export id' do
      get :show, params: { subscription_id: valid_subscription_id, id: data_export.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.to_s).to include(data_export.id.to_s)
      expect(json.to_s).to include(PublicUsers::DataExport::PROCESSING)
    end

    context 'when export does not exist' do
      it 'returns not found' do
        get :show, params: { subscription_id: valid_subscription_id, id: 123_456_789 }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when export belongs to another user' do
      let(:other_user) { create(:public_user) }
      let(:other_export) { create(:data_export, user: other_user) }

      it 'returns not found' do
        get :show, params: { subscription_id: valid_subscription_id, id: other_export.id }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #download' do
    let(:data_export) do
      create(
        :data_export,
        user: user,
        export_type: PublicUsers::DataExport::CCWL,
        status: PublicUsers::DataExport::COMPLETED,
        s3_key: 'data/export/2026-03-09/ccwl/1_test.xlsx',
        file_name: 'commodity_watch_list-your_codes_2026-03-09.xlsx',
      )
    end

    let(:storage_service) { instance_double(Api::User::DataExportService::StorageService) }

    before do
      allow(Api::User::DataExportService::StorageService).to receive(:new).and_return(storage_service)
      allow(storage_service).to receive(:download).with(key: data_export.s3_key).and_return('mock excel data')
    end

    it 'returns file bytes for a completed export' do
      get :download, params: { subscription_id: valid_subscription_id, id: data_export.id }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include(data_export.file_name)
      expect(response.body).to eq('mock excel data')
    end

    context 'when export is not completed' do
      before { data_export.update(status: PublicUsers::DataExport::PROCESSING) }

      it 'returns unprocessable entity' do
        get :download, params: { subscription_id: valid_subscription_id, id: data_export.id }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
