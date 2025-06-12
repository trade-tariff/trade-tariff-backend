RSpec.describe ExternalUserDeletionWorker, type: :worker do
  let(:user) { instance_spy(PublicUsers::User, id: 1, deleted: true, external_id: 'abc123') }

  before do
    allow(PublicUsers::User).to receive(:[]).with(user.id).and_return(user)
    allow(user).to receive(:update)
  end

  context 'when user is not deleted' do
    it 'returns without doing anything' do
      allow(user).to receive(:deleted).and_return(false)
      described_class.new.perform(user.id)
      expect(user).not_to have_received(:update)
    end
  end

  context 'when another active user with same external_id exists' do
    let(:active_user) { instance_spy(PublicUsers::User) }

    before do
      allow(user).to receive(:external_id).and_return('abc123')
      allow(PublicUsers::User).to receive_message_chain(:active, :where, :exclude, :first).and_return(active_user)
    end

    it 'removes external_id from deleted user and returns' do
      described_class.new.perform(user.id)
      expect(user).to have_received(:update).with(external_id: nil)
    end
  end

  context 'when no other active user with same external_id' do
    let(:worker) { described_class.new }

    before do
      allow(user).to receive(:external_id).and_return('abc123')
      allow(PublicUsers::User).to receive_message_chain(:active, :where, :exclude, :first).and_return(nil)
    end

    it 'calls identity API and removes external_id if successful' do
      allow(worker).to receive(:identity_api_delete).with('abc123').and_return(true)
      worker.perform(user.id)
      expect(user).to have_received(:update).with(external_id: nil)
    end

    it 'does not remove external_id if API call fails' do
      allow(worker).to receive(:identity_api_delete).with('abc123').and_return(false)
      worker.perform(user.id)
      expect(user).not_to have_received(:update).with(external_id: nil)
    end
  end
end
