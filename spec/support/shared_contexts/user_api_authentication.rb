RSpec.shared_context 'with user API authentication' do
  let(:user_token) { 'Bearer tariff-api-test-token' }
  let(:user_id) { 'user123' }
  let(:user) { create(:public_user, external_id: user_id) }
  let(:user_hash) { { 'sub' => user_id, 'email' => 'test@example.com' } }

  before do
    request.headers['Authorization'] = user_token
    allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(user_hash)
  end

  routes { UserApi.routes }
end
