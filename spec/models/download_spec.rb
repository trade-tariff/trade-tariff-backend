RSpec.describe Download do
  describe 'creating' do
    it 'does not enqueue a worker (the controller does that)' do
      allow(DownloadWorker).to receive(:perform_async)

      create :download

      expect(DownloadWorker).not_to have_received(:perform_async)
    end

    it 'does not default whodunnit from the current request' do
      TradeTariffRequest.whodunnit = 'request-user'

      expect(described_class.new).not_to be_valid
    ensure
      TradeTariffRequest.reset
    end
  end
end
