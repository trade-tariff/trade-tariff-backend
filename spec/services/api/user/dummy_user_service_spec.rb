RSpec.describe Api::User::DummyUserService do
  describe '.find_or_create' do
    before do
      allow(IdentityApiClient).to receive(:get_email).and_return('dummy@user.com')
    end

    context 'when not in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'returns nil' do
        expect(described_class.find_or_create).to be_nil
      end
    end

    context 'when in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      context 'when dummy user does not exist' do
        it 'creates a new dummy user with correct attributes' do
          expect {
            described_class.find_or_create
          }.to change(PublicUsers::User, :count).by(1)

          user = PublicUsers::User.last
          expect(user.external_id).to eq('dummy_user')
          expect(user.email).to eq('dummy@user.com')
        end
      end

      context 'when dummy user already exists' do
        let!(:existing_dummy_user) { create(:public_user, external_id: 'dummy_user') }

        it 'returns the existing dummy user' do
          expect {
            result = described_class.find_or_create
            expect(result).to eq(existing_dummy_user)
          }.not_to change(PublicUsers::User, :count)
        end

        it 'sets the email on the existing user' do
          user = described_class.find_or_create
          expect(user.email).to eq('dummy@user.com')
        end
      end

      context 'when dummy user exists but is soft deleted' do
        let!(:deleted_dummy_user) { create(:public_user, external_id: 'dummy_user', deleted: true) }

        it 'creates a new dummy user' do
          expect {
            described_class.find_or_create
          }.to change(PublicUsers::User, :count).by(1)

          # The new user should be different from the deleted one
          new_user = PublicUsers::User.active.last
          expect(new_user).not_to eq(deleted_dummy_user)
          expect(new_user.external_id).to eq('dummy_user')
          expect(new_user.deleted).to be false
        end
      end
    end
  end
end
