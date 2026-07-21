RSpec.shared_context 'with user API authentication' do
  let(:user) { create(:public_user, external_id: 'user123') }
  let(:user_token) { 'Bearer tariff-api-test-token' }
  let(:request_header_overrides) { { 'Authorization' => user_token } }

  before do
    user
    allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(
      CognitoTokenVerifier::Result.new(
        valid: true,
        payload: { 'sub' => user.external_id, 'email' => 'test@example.com' },
        reason: nil,
      ),
    )
  end
end
