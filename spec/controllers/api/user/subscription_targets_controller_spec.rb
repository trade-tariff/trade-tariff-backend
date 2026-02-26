RSpec.describe Api::User::SubscriptionTargetsController do
  include_context 'with user API authentication'

  let(:subscription) { create(:user_subscription, user: user, subscription_type: Subscriptions::Type.my_commodities) }
  let(:valid_subscription_id) { subscription.uuid }

  describe 'GET #index' do
    context 'when service returns targets' do
      let(:subscription_targets) do
        [
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '123', target_type: 'commodity'),
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '456', target_type: 'commodity'),
        ]
      end
      let(:service_instance) { instance_double(Api::User::TargetsFilterService::MyCommoditiesTargetsFilterService) }

      before do
        allow(subscription.filter)
          .to receive(:call)
          .with(nil, 1, 10)
          .and_return(service_instance)

        allow(service_instance)
          .to receive(:call)
          .and_return([subscription_targets, 2])

        get :index, params: { subscription_id: valid_subscription_id, page: 1, per_page: 10 }
      end

      it 'returns status 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns serialized targets with pagination metadata' do
        json = JSON.parse(response.body)

        serializer_output =
          Api::User::SubscriptionTargetSerializer
            .new(subscription_targets)
            .serializable_hash

        expect(json['data']).to eq(serializer_output[:data].as_json)

        expect(json['meta']).to eq(
          'pagination' => {
            'page' => 1,
            'per_page' => 10,
            'total_count' => 2,
          },
        )
      end
    end

    context 'when target filter service is not implemented' do
      let(:subscription) { create(:user_subscription, user: user, subscription_type: Subscriptions::Type.stop_press) }

      before do
        get :index, params: { subscription_id: valid_subscription_id }
      end

      it 'returns a bad request response' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ errors: [{ detail: 'Unsupported subscription type for targets filtering: stop_press' }] }.to_json)
      end
    end

    context 'when subscription is missing' do
      it 'returns unauthorized' do
        get :index, params: { subscription_id: SecureRandom.uuid }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when no auth token provided' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = nil
        get :index, params: { subscription_id: valid_subscription_id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #download' do
    let(:package) { instance_double(Axlsx::Package) }
    let(:stream) { StringIO.new('mock excel data') }
    let(:service) { instance_double(Api::User::ActiveCommoditiesService) }

    before do
      allow(Api::User::ActiveCommoditiesService).to receive(:new).with(subscription).and_return(service)
      allow(service).to receive(:generate_report).and_return(package)
      allow(package).to receive(:to_stream).and_return(stream)
    end

    it 'returns an Excel file with expected headers and body' do
      freeze_time do
        get :download, params: { subscription_id: valid_subscription_id }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('commodity_watch_list-your_codes_')
        expect(response.body).to eq('mock excel data')
      end
    end

    it 'builds the report from the current subscription' do
      get :download, params: { subscription_id: valid_subscription_id }

      expect(Api::User::ActiveCommoditiesService).to have_received(:new).with(subscription)
      expect(service).to have_received(:generate_report)
    end

    context 'when subscription is missing' do
      it 'returns unauthorized' do
        get :download, params: { subscription_id: SecureRandom.uuid }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when no auth token provided' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = nil
        get :download, params: { subscription_id: valid_subscription_id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
