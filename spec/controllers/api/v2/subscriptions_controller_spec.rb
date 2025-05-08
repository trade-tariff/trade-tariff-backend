RSpec.describe Api::V2::SubscriptionsController do
  routes { V2Api.routes }

  let(:subscription) { create(:user_subscription) }

  describe 'GET /subscriptions' do
    subject(:response) { get :index, params: { user_id: subscription.user_id } }

    it { expect(response).to have_http_status(:ok) }

    it { expect(JSON.parse(response.body)[0]['user_id']).to eq(subscription.user_id) }
  end

  describe 'PATCH /subscriptions/:id/unsubscribe' do
    it 'marks the subscription as inactive' do # rubocop:disable RSpec/MultipleExpectations
      response = patch :unsubscribe, params: { id: subscription.id, user_id: subscription.user_id }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['active']).to be_falsey
    end

    it 'responds appropriately when the subscription is not found' do # rubocop:disable RSpec/MultipleExpectations
      response = patch :unsubscribe, params: { id: SecureRandom.uuid, user_id: SecureRandom.uuid }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Subscription not found')
    end
  end

  describe 'DELETE /subscriptions/:id' do
    subject(:response) { delete :destroy, params: { id: subscription.id, user_id: subscription.user_id } }

    it { expect(response).to have_http_status(:ok) }
  end
end
