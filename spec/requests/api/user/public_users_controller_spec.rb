RSpec.describe Api::User::PublicUsersController do
  subject(:api_response) do
    make_request
    response
  end

  let(:request_header_overrides) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET #show' do
    let(:make_request) do
      get '/uk/user/users', headers: request_headers
      response
    end

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
          get '/uk/user/users', headers: request_headers
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

      it 'does not create a user' do
        expect {
          get '/uk/user/users', headers: request_headers
        }.not_to change(PublicUsers::User, :count)
      end

      it { is_expected.to have_http_status :not_found }

      it 'returns not found error payload' do
        api_response

        expect(response.parsed_body).to eq(
          'errors' => [{ 'detail' => 'User not found', 'code' => 'not_found' }],
        )
      end
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

      it 'does not create a user' do
        expect {
          get '/uk/user/users', headers: request_headers
        }.not_to change(PublicUsers::User, :count)
      end

      it { is_expected.to have_http_status :not_found }

      it 'returns not found error payload' do
        api_response

        expect(response.parsed_body).to eq(
          'errors' => [{ 'detail' => 'User not found', 'code' => 'not_found' }],
        )
      end
    end

    context 'when in development environment without valid token' do
      let(:token) { nil }
      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: false, payload: nil, reason: :missing_token) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
        allow(IdentityApiClient).to receive(:get_email).and_return('dummy@user.com')
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('MYOTT_AUTH_BYPASS').and_return(nil)
      end

      it 'uses dummy user service to create/find dummy user' do
        allow(Api::User::DummyUserService).to receive(:find_or_create).and_call_original

        expect {
          get '/uk/user/users', headers: request_headers
        }.to change(PublicUsers::User, :count).by(1)

        expect(Api::User::DummyUserService).to have_received(:find_or_create)

        dummy_user = PublicUsers::User.last
        expect(dummy_user.external_id).to eq('dummy_user')
        expect(dummy_user.email).to eq('dummy@user.com')
      end

      it { is_expected.to have_http_status :ok }

      context 'when the development bypass is disabled' do
        before do
          allow(ENV).to receive(:[]).with('MYOTT_AUTH_BYPASS').and_return('false')
          allow(Api::User::DummyUserService).to receive(:find_or_create)
        end

        it 'rejects requests without a token instead of returning the dummy user' do
          expect(api_response).to have_http_status(:unauthorized)
          expect(Api::User::DummyUserService).not_to have_received(:find_or_create)
        end

        context 'with a rejected token' do
          let(:token) { 'rejected-token' }

          %i[not_in_group invalid_token missing_token].each do |reason|
            it "does not create an account for #{reason}" do
              allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(
                CognitoTokenVerifier::Result.new(valid: false, payload: nil, reason: reason),
              )
              expect { api_response }.not_to change(PublicUsers::User, :count)
              expect(response).to have_http_status(:unauthorized)
              expect(Api::User::DummyUserService).not_to have_received(:find_or_create)

              expect { post '/uk/user/users', headers: request_headers }.not_to change(PublicUsers::User, :count)
              expect(response).not_to have_http_status(:created)
            end
          end
        end

        context 'with a new token account' do
          let(:token) { { 'sub' => 'new-local-account', 'email' => 'local@example.test' } }
          let(:verify_result) { CognitoTokenVerifier::Result.new(valid: true, payload: token, reason: nil) }

          before { allow(IdentityApiClient).to receive(:get_email).and_return('local@example.test') }

          it 'looks up then creates the real account' do
            expect(api_response).to have_http_status(:not_found)
            expect { post '/uk/user/users', headers: request_headers }.to change(PublicUsers::User, :count).by(1)
            expect(response).to have_http_status(:created)
            expect(PublicUsers::User.last.external_id).to eq('new-local-account')
            expect(Api::User::DummyUserService).not_to have_received(:find_or_create)
          end
        end

        context 'with a valid token' do
          let!(:user) { create(:public_user) }
          let(:token) { { 'sub' => user.external_id, 'email' => 'alice@example.com' } }
          let(:verify_result) { CognitoTokenVerifier::Result.new(valid: true, payload: token, reason: nil) }

          it 'returns the account from the token' do
            expect(api_response).to have_http_status(:ok)
            expect(response.parsed_body.dig('data', 'attributes', 'email')).to eq('alice@example.com')
            expect(Api::User::DummyUserService).not_to have_received(:find_or_create)
          end
        end
      end
    end
  end

  describe 'PATCH #update' do
    context 'when token is invalid' do
      let(:token) { nil }
      let(:make_request) do
        patch '/uk/user/users', params: { data: { attributes: { chapter_ids: '12,13,14' } } }, headers: request_headers, as: :json
        response
      end
      let(:verify_result) { CognitoTokenVerifier::Result.new(valid: false, payload: nil, reason: :missing_token) }

      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
      end

      it_behaves_like 'a unauthorised public user response for invalid bearer token'
    end

    context 'when chapter_ids are being updated' do
      let!(:user) { create(:public_user) }
      let(:make_request) do
        patch '/uk/user/users', params: { data: { attributes: { chapter_ids: '12,13,14' } } }, headers: request_headers, as: :json
        response
      end

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
        let(:make_request) do
          patch '/uk/user/users', params: { data: { attributes: { chapter_ids: '123' } } }, headers: request_headers, as: :json
          response
        end

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

  describe 'POST #create' do
    let(:make_request) { post '/uk/user/users', headers: request_headers }

    context 'when user already exists' do
      let!(:user) { create(:public_user) }
      let(:token) { 'tariff-api-test-token' }

      before do
        allow(Api::User::UserService).to receive(:find).with(token).and_return(user)
        allow(Api::User::UserService).to receive(:create)
      end

      it 'returns conflict' do
        expect(api_response).to have_http_status :conflict
      end

      it 'does not create a user' do
        api_response

        expect(Api::User::UserService).not_to have_received(:create)
      end

      it 'returns a user already exists error' do
        api_response

        expect(response.parsed_body).to eq(
          'errors' => [{ 'detail' => 'User already exists' }],
        )
      end
    end

    context 'when user does not exist' do
      let(:token) { 'tariff-api-test-token' }

      before do
        allow(Api::User::UserService).to receive(:find).with(token).and_return(nil)
        allow(Api::User::UserService).to receive(:create)
      end

      it 'returns created' do
        expect(api_response).to have_http_status :created
      end

      it 'creates the user from token' do
        api_response

        expect(Api::User::UserService).to have_received(:create).with(token)
      end

      it 'returns jsonapi payload' do
        api_response

        expect(response.parsed_body).to include('data')
      end
    end
  end
end
