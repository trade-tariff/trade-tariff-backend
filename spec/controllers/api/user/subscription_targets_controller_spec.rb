RSpec.describe Api::User::SubscriptionTargetsController do
  routes { UserApi.routes }

  let(:user_token) { 'Bearer tariff-api-test-token' }
  let(:user_id) { 'user123' }
  let(:user) { create(:public_user, external_id: user_id) }
  let(:user_hash) { { 'sub' => user_id, 'email' => 'test@example.com' } }
  let(:subscription) { create(:user_subscription, user: user) }
  let(:valid_subscription_id) { subscription.uuid }
  let(:invalid_subscription_id) { SecureRandom.uuid }

  before do
    request.headers['Authorization'] = user_token
    allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(user_hash)
  end

  describe 'GET #show' do
    context 'with a valid subscription and no filter' do
      let!(:subscription_targets) do
        [
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '123', target_type: 'commodity'),
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '456', target_type: 'commodity'),
        ]
      end

      before do
        get :show, params: { id: valid_subscription_id }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns all subscription targets without commodities' do
        expected_targets = subscription_targets.map do |st|
          target = PublicUsers::SubscriptionTarget.new
          target.virtual_id = st.id
          target.target_type = st.target_type
          target.commodity = nil
          target
        end

        serialized_data = Api::User::SubscriptionTargetSerializer.new(expected_targets).serializable_hash

        expected_response = {
          data: serialized_data[:data],
          meta: {
            pagination: {
              page: 1,
              per_page: 20,
              total_count: subscription_targets.size,
            },
          },
        }

        expect(JSON.parse(response.body)).to eq(JSON.parse(expected_response.to_json))
      end
    end

    context 'with active_commodities_type filter and pagination' do
      let!(:commodity_1) { create(:commodity, goods_nomenclature_sid: 789, goods_nomenclature_item_id: '1234567890', producline_suffix: '80') }
      let!(:commodity_2) { create(:commodity, goods_nomenclature_sid: 101, goods_nomenclature_item_id: '1234567891', producline_suffix: '80') }

      let(:active_targets) do
        [
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: commodity_1.goods_nomenclature_sid, target_type: 'commodity'),
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: commodity_2.goods_nomenclature_sid, target_type: 'commodity'),
        ]
      end

      before do
        active_targets
        service_instance = instance_double(Api::User::ActiveCommoditiesService)
        allow(Api::User::ActiveCommoditiesService).to receive(:new).with(subscription).and_return(service_instance)
        allow(service_instance).to receive(:respond_to?).with('active_commodities').and_return(true)
        allow(service_instance).to receive(:active_commodities).and_return([[commodity_1, commodity_2], 2])

        get :show, params: { id: valid_subscription_id, filter: { active_commodities_type: 'active' }, page: 1, per_page: 1 }
      end

      it 'returns paginated results' do
        json = JSON.parse(response.body)
        expect(json['meta']['pagination']).to include('page' => 1, 'per_page' => 1, 'total_count' => 2)
      end

      it 'returns only commodities with producline_suffix 80' do
        json = JSON.parse(response.body)
        suffixes = json['data'].map { |d| d['attributes']['producline_suffix'] }
        expect(suffixes).to all(eq('80'))
      end

      it 'calls ActiveCommoditiesService with the subscription' do
        expect(Api::User::ActiveCommoditiesService).to have_received(:new).with(subscription)
      end
    end

    context 'with unknown filter value' do
      before do
        service_instance = instance_double(Api::User::ActiveCommoditiesService)
        allow(Api::User::ActiveCommoditiesService).to receive(:new).with(subscription).and_return(service_instance)
        allow(service_instance).to receive(:call).and_return({})

        get :show, params: { id: valid_subscription_id, filter: { active_commodities_type: 'inactive' } }
      end

      it 'returns an empty data array' do
        expect(JSON.parse(response.body)).to eq({ 'data' => [], 'meta' => { 'pagination' => { 'page' => 1, 'per_page' => 20, 'total_count' => 0 } } })
      end
    end

    context 'with an invalid subscription ID' do
      before { get :show, params: { id: invalid_subscription_id } }

      it 'returns unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders error message' do
        expect(response.body).to eq({ message: 'No subscription ID was provided' }.to_json)
      end
    end

    context 'without authorization token' do
      before do
        request.headers['Authorization'] = nil
        get :show, params: { id: valid_subscription_id }
      end

      it 'returns unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders error message' do
        expect(response.body).to eq({ message: 'No bearer token was provided' }.to_json)
      end
    end
  end
end
