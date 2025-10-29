RSpec.describe Api::User::SubscriptionsController do
  routes { UserApi.routes }

  let(:subscription) { create(:user_subscription) }
  let(:valid_token) { subscription.uuid }
  let(:invalid_token) { 'invalid_token' }

  describe 'GET #show' do
    context 'when a valid token is provided' do
      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: valid_token).and_return(subscription)
        get :show, params: { id: valid_token }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'renders the serialized subscription' do
        serialized_subscription = Api::User::SubscriptionSerializer.new(subscription).serializable_hash
        expect(response.body).to eq(serialized_subscription.to_json)
      end
    end

    context 'when an invalid token is provided' do
      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: invalid_token).and_return(nil)
        get :show, params: { id: invalid_token }
      end

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ message: 'No token was provided' }.to_json)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when a valid token is provided' do
      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: valid_token).and_return(subscription)
        allow(subscription).to receive(:unsubscribe)
        post :destroy, params: { id: valid_token }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'calls unsubscribe on the subscription' do
        expect(subscription).to have_received(:unsubscribe)
      end
    end

    context 'when an invalid token is provided' do
      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: invalid_token).and_return(nil)
        post :destroy, params: { id: invalid_token }
      end

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ message: 'No token was provided' }.to_json)
      end
    end
  end

  describe '#create_batch' do
    let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.my_commodities.id) }
    let(:targets) { %w[1234567890 1234567891 1234567892] }

    context 'when a valid token is provided with a supported subscription type' do
      before do
        create(:commodity, goods_nomenclature_item_id: '1234567890', goods_nomenclature_sid: 123)
        post :create_batch, params: { id: valid_token, data: { attributes: { subscription_type: 'my_commodities', targets: targets } } }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the subscription metadata for commodity_codes' do
        subscription.reload
        expect(subscription.metadata['commodity_codes']).to eq(targets)
      end

      it 'updates subscription targets with a commodity and ignores the other two' do
        targets = subscription.subscription_targets_dataset

        expect(targets.commodities.count).to eq(1)
        expect(targets.commodities.map(&:target_id)).to contain_exactly(123)
      end
    end

    context 'when an invalid token is provided' do
      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: invalid_token).and_return(nil)
        post :create_batch, params: { id: invalid_token, data: { attributes: { targets: targets } } }
      end

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ message: 'No token was provided' }.to_json)
      end
    end

    context 'when the user attempts to batch a stop press subscription' do
      let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.stop_press.id) }

      before do
        post :create_batch, params: { id: valid_token, data: { attributes: { subscription_type: 'stop_press', targets: targets } } }
      end

      it 'returns a bad request response' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ errors: [{ detail: 'Unsupported subscription type for batching: stop_press' }] }.to_json)
      end
    end

    context 'when the user attempts to batch my commodities but does not have a subscription' do
      let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.stop_press.id) }

      before do
        post :create_batch, params: { id: valid_token, data: { attributes: { subscription_type: 'my_commodities', targets: targets } } }
      end

      it 'returns a bad request response' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ errors: [{ detail: 'Unsupported subscription type for batching: my_commodities' }] }.to_json)
      end
    end
  end
end
