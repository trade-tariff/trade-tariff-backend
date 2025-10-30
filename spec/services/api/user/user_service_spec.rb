RSpec.describe Api::User::UserService do
  describe '.find_or_create' do
    let(:external_id) { 'test-user-123' }
    let(:email) { 'test@example.com' }
    let(:valid_payload) { { 'sub' => external_id, 'email' => email } }
    let(:token) { 'valid.jwt.token' }

    before do
      allow(CognitoTokenVerifier).to receive(:verify_id_token)
      allow(IdentityApiClient).to receive(:get_email) do |external_id_param|
        if external_id_param == external_id
          email
        else
          'fallback@example.com'
        end
      end
    end

    context 'when token is nil' do
      it 'returns nil' do
        result = described_class.find_or_create(nil)
        expect(result).to be_nil
      end

      it 'does not call CognitoTokenVerifier' do
        described_class.find_or_create(nil)
        expect(CognitoTokenVerifier).not_to have_received(:verify_id_token)
      end
    end

    context 'when token verification fails' do
      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).with(token).and_return(nil)
      end

      it 'returns nil' do
        result = described_class.find_or_create(token)
        expect(result).to be_nil
      end

      it 'calls CognitoTokenVerifier with the token' do
        described_class.find_or_create(token)
        expect(CognitoTokenVerifier).to have_received(:verify_id_token).with(token)
      end
    end

    context 'when token verification succeeds' do
      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).with(token).and_return(valid_payload)
      end

      context 'when user does not exist' do
        it 'creates a new user with correct attributes' do
          expect {
            described_class.find_or_create(token)
          }.to change(PublicUsers::User, :count).by(1)

          user = PublicUsers::User.last
          expect(user.external_id).to eq(external_id)
          expect(user.email).to eq(email)
        end

        it 'returns the newly created user' do
          result = described_class.find_or_create(token)
          expect(result).to be_a(PublicUsers::User)
          expect(result.external_id).to eq(external_id)
          expect(result.email).to eq(email)
        end

        it 'calls CognitoTokenVerifier with the token' do
          described_class.find_or_create(token)
          expect(CognitoTokenVerifier).to have_received(:verify_id_token).with(token)
        end
      end

      context 'when active user already exists' do
        let!(:existing_user) { create(:public_user, external_id: external_id) }

        it 'does not create a new user' do
          expect {
            described_class.find_or_create(token)
          }.not_to change(PublicUsers::User, :count)
        end

        it 'returns the existing user' do
          result = described_class.find_or_create(token)
          expect(result).to eq(existing_user)
        end

        it 'updates the email on the existing user' do
          allow(IdentityApiClient).to receive(:get_email).with(external_id).and_return('old@example.com')
          original_email = existing_user.email

          allow(IdentityApiClient).to receive(:get_email).with(external_id).and_return(email)

          result = described_class.find_or_create(token)

          expect(result.email).to eq(email)
          expect(result.email).not_to eq(original_email)
        end

        it 'calls CognitoTokenVerifier with the token' do
          described_class.find_or_create(token)
          expect(CognitoTokenVerifier).to have_received(:verify_id_token).with(token)
        end
      end

      context 'when soft-deleted user exists with same external_id' do
        let!(:deleted_user) { create(:public_user, :has_been_soft_deleted, external_id: external_id) }

        it 'creates a new user instead of using the deleted one' do
          expect {
            described_class.find_or_create(token)
          }.to change(PublicUsers::User, :count).by(1)

          # The new user should be different from the deleted one
          new_user = PublicUsers::User.active.last
          expect(new_user).not_to eq(deleted_user)
          expect(new_user.external_id).to eq(external_id)
          expect(new_user.deleted).to be false
        end

        it 'returns the newly created active user' do
          result = described_class.find_or_create(token)
          expect(result).to be_a(PublicUsers::User)
          expect(result.external_id).to eq(external_id)
          expect(result.email).to eq(email)
          expect(result.deleted).to be false
        end
      end

      context 'when payload has different email formats' do
        let(:email_with_plus) { 'test+label@example.com' }
        let(:payload_with_plus) { { 'sub' => external_id, 'email' => email_with_plus } }

        before do
          allow(CognitoTokenVerifier).to receive(:verify_id_token).with(token).and_return(payload_with_plus)
        end

        it 'correctly sets the email from the payload' do
          result = described_class.find_or_create(token)
          expect(result.email).to eq(email_with_plus)
        end
      end

      context 'when payload is missing email' do
        let(:payload_without_email) { { 'sub' => external_id } }

        before do
          allow(CognitoTokenVerifier).to receive(:verify_id_token).with(token).and_return(payload_without_email)
          allow(IdentityApiClient).to receive(:get_email).with(external_id).and_return(nil)
        end

        it 'creates user with nil email' do
          result = described_class.find_or_create(token)
          expect(result.external_id).to eq(external_id)
          expect(result.email).to be_nil
        end
      end

      context 'when payload is missing sub' do
        let(:payload_without_sub) { { 'email' => email } }

        before do
          allow(CognitoTokenVerifier).to receive(:verify_id_token).with(token).and_return(payload_without_sub)
        end

        it 'creates user with nil external_id' do
          result = described_class.find_or_create(token)
          expect(result.external_id).to be_nil
          expect(result.email).to eq(email)
        end
      end
    end

    context 'when CognitoTokenVerifier raises an exception' do
      before do
        allow(CognitoTokenVerifier).to receive(:verify_id_token).with(token).and_raise(StandardError, 'Token verification failed')
      end

      it 'propagates the exception' do
        expect {
          described_class.find_or_create(token)
        }.to raise_error(StandardError, 'Token verification failed')
      end
    end
  end
end
