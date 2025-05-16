RSpec.describe Api::User::UsersController do
  describe 'GET #show' do
    before do
      request.headers['Authorization'] = "Bearer #{token}"
      allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(token)
    end

    context 'when token is invalid' do
      subject(:rendered) { make_request && response }

      let(:token) { nil }
      let(:make_request) { get :show }

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    describe 'when token is for existing user' do
      let!(:user) { create(:public_user) }

      let(:token) do
        {
          'sub' => user.external_id,
          'email' => 'alice@example.com',
        }
      end

      it 'does not create a user' do
        expect {
          get :show
        }.not_to change(PublicUsers::User, :count)
      end

      it 'returns a successful response' do
        get :show
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'when token is for new user' do
      let(:token) do
        {
          'sub' => '0d6ed044-ab69-43ef-b69a-be84da6eabfc',
          'email' => 'alice@example.com',
        }
      end

      it 'creates a user' do
        expect {
          get :show
        }.to change(PublicUsers::User, :count).by 1
      end

      it 'returns a successful response' do
        get :show
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
