RSpec.describe Api::User::SubscriptionTargetsController do
  routes { UserApi.routes }

  let(:user_token) { 'Bearer tariff-api-test-token' }
  let(:user_id) { 'user123' }
  let(:user) { create(:public_user, external_id: user_id) }
  let(:user_hash) { { 'sub' => user_id, 'email' => 'test@example.com' } }
  let(:subscription) { create(:user_subscription, user: user) }
  let(:valid_subscription_id) { subscription.uuid }
  let(:invalid_subscription_id) { SecureRandom.uuid }
  let(:commodity) { create(:commodity, :actual, goods_nomenclature_item_id: '1234567890', goods_nomenclature_sid: 123) }

  before do
    request.headers['Authorization'] = user_token
    allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(user_hash)
  end

  describe 'GET #index' do
    context 'when a valid subscription id is provided' do
      let!(:subscription_targets) do
        [
          create(:subscription_target,
                 user_subscriptions_uuid: subscription.uuid,
                 target_id: '123',
                 target_type: 'commodity'),
          create(:subscription_target,
                 user_subscriptions_uuid: subscription.uuid,
                 target_id: '456',
                 target_type: 'commodity'),
        ]
      end

      context 'without filter parameter' do
        before do
          get :show, params: {
            id: valid_subscription_id,
          }
        end

        it 'returns a successful response' do
          expect(response).to have_http_status(:ok)
        end

        it 'renders the serialized subscription targets' do
          serialized = Api::User::SubscriptionTargetSerializer.new(subscription_targets).serializable_hash
          expect(response.body).to eq(serialized.to_json)
        end
      end

      # rubocop:disable RSpec/MultipleMemoizedHelpers
      context 'with active_commodities_type filter' do
        let!(:commodity_1) { create(:commodity, goods_nomenclature_sid: 789, goods_nomenclature_item_id: '1234567890') }
        let!(:commodity_2) { create(:commodity, goods_nomenclature_sid: 101, goods_nomenclature_item_id: '1234567891') }

        let!(:active_targets) do
          [
            create(:subscription_target,
                   user_subscriptions_uuid: subscription.uuid,
                   target_id: commodity_1.goods_nomenclature_sid,
                   target_type: 'commodity'),
            create(:subscription_target,
                   user_subscriptions_uuid: subscription.uuid,
                   target_id: commodity_2.goods_nomenclature_sid,
                   target_type: 'commodity'),
          ]
        end

        before do
          service_response = { active: [commodity_1.goods_nomenclature_item_id, commodity_2.goods_nomenclature_item_id] }
          active_commodities_service = instance_double(Api::User::ActiveCommoditiesService)

          allow(Api::User::ActiveCommoditiesService).to receive(:new)
            .with(subscription)
            .and_return(active_commodities_service)
          allow(active_commodities_service).to receive(:call).and_return(service_response)

          get :show, params: {
            id: valid_subscription_id,
            filter: { active_commodities_type: 'active' },
          }
        end

        it 'returns a successful response' do
          expect(response).to have_http_status(:ok)
        end

        it 'calls ActiveCommoditiesService with correct parameters' do
          expect(Api::User::ActiveCommoditiesService).to have_received(:new).with(subscription)
        end

        it 'extracts the correct filter key from service response' do
          serialized = TimeMachine.now { Api::User::SubscriptionTargetSerializer.new(active_targets).serializable_hash }
          expect(response.body).to eq(serialized.to_json)
        end

        it 'uses the filter parameter as the key to access service results' do
          # Verify that we're accessing the service response with the filter key
          expect(Api::User::ActiveCommoditiesService).to have_received(:new)
          # The response should contain the filtered commodities from the 'active_commodities_type' key
        end
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      context 'with unknown filter value' do
        before do
          active_commodities_service = instance_double(Api::User::ActiveCommoditiesService)

          allow(Api::User::ActiveCommoditiesService).to receive(:new)
            .with(subscription)
            .and_return(active_commodities_service)
          allow(active_commodities_service).to receive(:call).and_return({})

          get :show, params: {
            id: valid_subscription_id,
            filter: { active_commodities_type: 'inactive' },
          }
        end

        it 'returns a successful response' do
          expect(response).to have_http_status(:ok)
        end

        it 'calls ActiveCommoditiesService with correct parameters' do
          expect(Api::User::ActiveCommoditiesService).to have_received(:new)
        end

        it 'returns empty array for unknown filter value' do
          expect(response.body).to eq({ data: [] }.to_json)
        end
      end
    end

    context 'when an invalid subscription id is provided' do
      before do
        get :show, params: {
          id: invalid_subscription_id,
        }
      end

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ message: 'No subscription ID was provided' }.to_json)
      end
    end

    context 'when no authorization token is provided' do
      before do
        request.headers['Authorization'] = nil
        get :show, params: {
          id: valid_subscription_id,
        }
      end

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ message: 'No bearer token was provided' }.to_json)
      end
    end
  end
end
