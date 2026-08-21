RSpec.describe WatchListInvitationEmailWorker, type: :worker do
  describe 'sidekiq options' do
    it 'caps retries below Sidekiq default' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end
end
