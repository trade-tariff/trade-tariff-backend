RSpec.describe ExternalUserDeletionWorker, type: :worker do
  let(:user) { create(:public_user, deleted: true, external_id: 'abc123') }
  let(:worker) { described_class.new }

  before do
    allow(PublicUsers::User).to receive(:[]).with(user.id).and_return(user)
  end

  context 'when user is not deleted' do
    it 'returns without doing anything' do
      allow(user).to receive(:deleted).and_return(false)

      expect {
        worker.perform(user.id)
      }.not_to change(user, :external_id)
    end
  end

  context 'when another active user with same external_id exists' do
    let(:active_user) { instance_spy(PublicUsers::User) }

    before do
      allow(PublicUsers::User).to receive_message_chain(:active, :where, :exclude, :first).and_return(active_user)
    end

    it 'removes external_id from deleted user and returns' do
      expect {
        worker.perform(user.id)
      }.to change(user, :external_id).from('abc123').to(nil)
    end
  end

  context 'when no other active user with same external_id' do
    before do
      allow(PublicUsers::User).to receive_message_chain(:active, :where, :exclude, :first).and_return(nil)
    end

    it 'calls identity API and removes external_id if successful' do
      allow(IdentityApiClient).to receive(:delete_user).and_return(true)

      expect {
        worker.perform(user.id)
      }.to change(user, :external_id).from('abc123').to(nil)
    end

    it 'does not remove external_id if API call fails' do
      allow(IdentityApiClient).to receive(:delete_user).and_return(false)

      expect {
        worker.perform(user.id)
      }.not_to change(user, :external_id)
    end
  end
end
