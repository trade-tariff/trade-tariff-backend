RSpec.describe Api::User::SubscriptionsController do
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
end
