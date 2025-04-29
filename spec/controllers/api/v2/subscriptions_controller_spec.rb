RSpec.describe Api::V2::SubscriptionsController do
  routes { V2Api.routes }

  before do
    user = create(:public_user)
    raise user.inspect
    create(:user_subscription)
  end

  describe 'GET /subscriptions' do
    subject(:response) { get :index, params: { user_id: subscription.user_id } }

    it { expect(response).to have_http_status(:ok) }
  end
end
