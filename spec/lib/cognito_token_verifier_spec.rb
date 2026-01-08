RSpec.describe CognitoTokenVerifier do
  describe '.verify_id_token' do
    let(:token) { 'test-token' }
    let(:jwks_url) { "https://cognito-idp.#{ENV['AWS_REGION']}.amazonaws.com/#{ENV['COGNITO_USER_POOL_ID']}/.well-known/jwks.json" }
    let(:jwks_keys) { { 'keys' => [{ 'kty' => 'RSA', 'kid' => 'test-kid', 'use' => 'sig' }] } }
    let(:decoded_token) { [{ 'sub' => '1234567890', 'email' => 'test@example.com', 'cognito:groups' => %w[myott] }] }

    before do
      allow(Faraday).to receive(:get).with(jwks_url).and_return(instance_double(Faraday::Response, success?: true, body: jwks_keys.to_json))
      allow(EncryptionService).to receive(:decrypt_string).and_return(token)
      allow(JWT).to receive(:decode).and_return(decoded_token)
    end

    context 'when the token is valid' do
      it 'returns a valid Result with payload' do
        result = described_class.verify_id_token(token)
        expect(result).to be_a(described_class::Result)
        expect(result.valid?).to be true
        expect(result.payload).to eq(decoded_token[0])
        expect(result.reason).to be_nil
      end

      it 'verifies the token' do
        described_class.verify_id_token(token)
        expect(JWT).to have_received(:decode).with(token, nil, true, algorithms: %w[RS256], jwks: hash_including(:keys), iss: anything, verify_iss: true)
      end
    end

    context 'when the token is valid but not in the expected group' do
      let(:decoded_token) { [{ 'sub' => '1234567890', 'email' => 'test@example.com', 'cognito:groups' => %w[other] }] }

      it 'returns invalid Result with not_in_group reason' do
        result = described_class.verify_id_token(token)
        expect(result).to be_a(described_class::Result)
        expect(result.valid?).to be false
        expect(result.payload).to be_nil
        expect(result.reason).to eq(:not_in_group)
      end
    end

    context 'when the token is blank' do
      let(:token) { nil }

      it 'returns invalid Result with missing_token reason' do
        result = described_class.verify_id_token(token)
        expect(result).to be_a(described_class::Result)
        expect(result.valid?).to be false
        expect(result.payload).to be_nil
        expect(result.reason).to eq(:missing_token)
      end
    end

    context 'when the JWKS response is unsuccessful' do
      before do
        allow(Faraday).to receive(:get).with(jwks_url).and_return(instance_double(Faraday::Response, success?: false))
      end

      it 'returns invalid Result with missing_jwks_keys reason' do
        result = described_class.verify_id_token(token)
        expect(result).to be_a(described_class::Result)
        expect(result.valid?).to be false
        expect(result.payload).to be_nil
        expect(result.reason).to eq(:missing_jwks_keys)
      end
    end

    context 'when token has expired' do
      before do
        allow(JWT).to receive(:decode).and_raise(JWT::ExpiredSignature)
      end

      it 'returns invalid Result with expired reason' do
        result = described_class.verify_id_token(token)
        expect(result).to be_a(described_class::Result)
        expect(result.valid?).to be false
        expect(result.expired?).to be true
        expect(result.payload).to be_nil
        expect(result.reason).to eq(:expired)
      end
    end

    context 'when an error occurs during token verification' do
      before do
        allow(JWT).to receive(:decode).and_raise(JWT::DecodeError)
      end

      it 'returns invalid Result with invalid_token reason' do
        result = described_class.verify_id_token(token)
        expect(result).to be_a(described_class::Result)
        expect(result.valid?).to be false
        expect(result.payload).to be_nil
        expect(result.reason).to eq(:invalid_token)
      end
    end
  end
end
