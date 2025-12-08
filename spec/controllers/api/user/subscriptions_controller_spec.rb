RSpec.describe Api::User::SubscriptionsController do
  include_context 'with user API authentication'

  let(:subscription) { create(:user_subscription, user: user) }
  let(:valid_id) { subscription.uuid }
  let(:invalid_id) { '00000000-0000-0000-0000-000000000000' }

  describe '#show' do
    let(:subscription) do
      create(:user_subscription,
             subscription_type_id: Subscriptions::Type.my_commodities.id,
             metadata: { commodity_codes: %w[1234567890 1234567891 9999999999],
                         measures: %w[1234567892] },
             user: user)
    end

    context 'when a valid ID is provided with a my commodities subscription type' do
      let(:subscription_type) { create(:subscription_type, name: 'my_commodities') }

      before do
        commodity_active = create(:commodity, :actual, goods_nomenclature_item_id: '1234567890')
        commodity_expired = create(:commodity, :expired, goods_nomenclature_item_id: '1234567891')
        measure = create(:measure, goods_nomenclature_item_id: '1234567892')

        create(:subscription_target,
               user_subscriptions_uuid: subscription.uuid,
               target_id: commodity_active.goods_nomenclature_sid,
               target_type: 'commodity')
        create(:subscription_target,
               user_subscriptions_uuid: subscription.uuid,
               target_id: commodity_expired.goods_nomenclature_sid,
               target_type: 'commodity')
        create(:subscription_target,
               user_subscriptions_uuid: subscription.uuid,
               target_id: measure.goods_nomenclature_sid,
               target_type: 'measure')

        get :show, params: { id: valid_id }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns serialized meta with target commodity codes sorted into correct groups' do
        serialized_subscription =
          Api::User::SubscriptionSerializer.new(subscription, include: [:subscription_type]).serializable_hash
        expect(JSON.parse(response.body)).to eq(JSON.parse(serialized_subscription.to_json))
      end
    end

    context 'when an invalid id is provided' do
      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: invalid_id).and_return(nil)
        get :show, params: { id: invalid_id }
      end

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ message: 'No subscription ID was provided' }.to_json)
      end
    end

    context 'when the subscription is stop_press' do
      let(:subscription) do
        create(:user_subscription,
               subscription_type_id: Subscriptions::Type.stop_press.id,
               user: user)
      end

      before do
        get :show, params: { id: valid_id }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns subscription without meta' do
        serialized_subscription =
          Api::User::SubscriptionSerializer.new(subscription, include: [:subscription_type]).serializable_hash
        expect(response.body).to eq(serialized_subscription.to_json)
      end
    end
  end

  describe '#destroy' do
    let(:user_token) { '' } # No user token is needed for unsubscribing

    context 'when a valid ID is provided' do
      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: valid_id).and_return(subscription)
        allow(subscription).to receive(:unsubscribe)
        post :destroy, params: { id: valid_id }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'calls unsubscribe on the subscription' do
        expect(subscription).to have_received(:unsubscribe)
      end
    end

    context 'when an invalid ID is provided' do
      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: invalid_id).and_return(nil)
        post :destroy, params: { id: invalid_id }
      end

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ message: 'No subscription ID was provided' }.to_json)
      end
    end
  end

  describe '#create_batch' do
    let(:targets) { %w[1234567890 1234567891 1234567892] }

    context 'when a valid token is provided with a supported subscription type' do
      let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.my_commodities.id, user: user) }

      before do
        create(:commodity, goods_nomenclature_item_id: '1234567890', goods_nomenclature_sid: 123)
        post :create_batch, params: { id: valid_id, data: { attributes: { targets: targets } } }
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
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: invalid_id).and_return(nil)
        post :create_batch, params: { id: invalid_id, data: { attributes: { targets: targets } } }
      end

      it 'returns an unauthorized response' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ message: 'No subscription ID was provided' }.to_json)
      end
    end

    context 'when the user attempts to batch a stop press subscription' do
      let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.stop_press.id, user: user) }

      before do
        allow(PublicUsers::Subscription).to receive(:find).with(uuid: valid_id).and_return(subscription)
        post :create_batch, params: { id: valid_id, data: { attributes: { targets: targets } } }
      end

      it 'returns a bad request response' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ errors: [{ detail: 'Unsupported subscription type for batching: stop_press' }] }.to_json)
      end
    end

    context 'when no subscription type is provided' do
      before do
        post :create_batch, params: { id: valid_id, data: { attributes: { targets: targets } } }
      end

      it 'returns a bad request response' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'renders an error message' do
        expect(response.body).to eq({ errors: [{ detail: 'Unsupported subscription type for batching: test' }] }.to_json)
      end
    end
  end
end
