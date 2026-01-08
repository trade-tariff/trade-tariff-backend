RSpec.describe Api::User::PublicUsersController do
  subject(:api_response) { make_request && response }

  routes { UserApi.routes }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'GET #show' do
    let(:make_request) { get :show }

    context 'when token is invalid' do
      let(:token) { nil }
      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: false, payload: nil, reason: :missing_token) }

      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
      end

      it_behaves_like 'a unauthorised public user response for invalid bearer token'
    end

    describe 'when token is for existing user' do
      let!(:user) { create(:public_user) }

      let(:token) do
        {
          'sub' => user.external_id,
          'email' => 'alice@example.com',
        }
      end

      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: true, payload: token, reason: nil) }

      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
      end

      it 'does not create a user' do
        expect {
          get :show
        }.not_to change(PublicUsers::User, :count)
      end

      it { is_expected.to have_http_status :ok }
    end

    describe 'when token is for new user' do
      let(:token) do
        {
          'sub' => '0d6ed044-ab69-43ef-b69a-be84da6eabfc',
          'email' => 'alice@example.com',
        }
      end

      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: true, payload: token, reason: nil) }

      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
      end

      it 'creates a user' do
        expect {
          get :show
        }.to change(PublicUsers::User, :count).by 1
      end

      it { is_expected.to have_http_status :ok }
    end

    describe 'when token is for deleted user' do
      let!(:user) { create(:public_user, :has_been_soft_deleted) }
      let(:token) do
        {
          'sub' => user.external_id,
          'email' => 'alice@example.com',
        }
      end

      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: true, payload: token, reason: nil) }

      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
      end

      it 'creates a user' do
        expect {
          get :show
        }.to change(PublicUsers::User, :count).by 1
      end

      it { is_expected.to have_http_status :ok }
    end

    context 'when in development environment without valid token' do
      let(:token) { nil }
      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: false, payload: nil, reason: :missing_token) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
        allow(IdentityApiClient).to receive(:get_email).and_return('dummy@user.com')
      end

      it 'uses dummy user service to create/find dummy user' do
        allow(Api::User::DummyUserService).to receive(:find_or_create).and_call_original

        expect {
          get :show
        }.to change(PublicUsers::User, :count).by(1)

        expect(Api::User::DummyUserService).to have_received(:find_or_create)

        dummy_user = PublicUsers::User.last
        expect(dummy_user.external_id).to eq('dummy_user')
        expect(dummy_user.email).to eq('dummy@user.com')
      end

      it { is_expected.to have_http_status :ok }
    end
  end

  describe 'PATCH #update' do
    context 'when token is invalid' do
      let(:token) { nil }
      let(:make_request) { patch :update, params: { data: { attributes: { chapter_ids: '12,13,14' } } } }
      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: false, payload: nil, reason: :missing_token) }

      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
      end

      it_behaves_like 'a unauthorised public user response for invalid bearer token'
    end

    context 'when chapter_ids are being updated' do
      let!(:user) { create(:public_user) }
      let(:make_request) { patch :update, params: { data: { attributes: { chapter_ids: '12,13,14' } } } }

      let(:token) do
        {
          'sub' => user.external_id,
          'email' => 'alice@example.com',
        }
      end

      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: true, payload: token, reason: nil) }

      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
      end

      it 'updates the chapter_ids' do
        api_response
        expect(user.chapter_ids).to eq '12,13,14'
      end

      it 'responds with updated chapter details' do
        expect(JSON.parse(api_response.body)['data']['attributes']['chapter_ids']).to eq '12,13,14'
      end

      it { is_expected.to have_http_status :ok }

      context 'with invalid params' do
        let(:make_request) { patch :update, params: { data: { attributes: { chapter_ids: '123' } } } }

        it 'returns errors for user' do
          expected = {
            'errors' => [
              {
                'detail' => 'chapter_ids is invalid',
              },
            ],
          }
          expect(JSON.parse(api_response.body)).to eq expected
        end

        it { is_expected.to have_http_status :unprocessable_content }
      end
    end

    it_behaves_like 'a user controller subscription type update', :stop_press_subscription
    it_behaves_like 'a user controller subscription type update', :my_commodities_subscription
  end
end
