RSpec.describe ExternalUserDeletionWorker, type: :worker do
  let(:user) { create(:public_user, deleted: true, external_id: 'abc123') }
  let(:worker) { described_class.new }

  before do
    allow(PublicUsers::User).to receive(:[]).with(user.id).and_return(user)
  end

  describe 'sidekiq options' do
    it 'caps retries below Sidekiq default' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
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
    before do
      stub_active_user_lookup(instance_spy(PublicUsers::User))
    end

    it 'removes external_id from deleted user and returns' do
      expect {
        worker.perform(user.id)
      }.to change(user, :external_id).from('abc123').to(nil)
    end
  end

  context 'when no other active user with same external_id' do
    before do
      stub_active_user_lookup(nil)
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

  def stub_active_user_lookup(result)
    active_users = instance_double(Sequel::Dataset)
    users_with_external_id = instance_double(Sequel::Dataset)
    other_users = instance_double(Sequel::Dataset)

    allow(PublicUsers::User).to receive(:active).and_return(active_users)
    allow(active_users).to receive(:where).with(external_id: user.external_id).and_return(users_with_external_id)
    allow(users_with_external_id).to receive(:exclude).with(id: user.id).and_return(other_users)
    allow(other_users).to receive(:first).and_return(result)
  end
end
