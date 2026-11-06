RSpec.describe Apply do
  describe 'creating' do
    it 'does not enqueue a worker (the controller does that)' do
      allow(ApplyWorker).to receive(:perform_async)

      create :apply

      expect(ApplyWorker).not_to have_received(:perform_async)
    end

    it 'does not default whodunnit from the current request' do
      TradeTariffRequest.whodunnit = 'request-user'

      expect(described_class.new).not_to be_valid
    ensure
      TradeTariffRequest.reset
    end
  end
end
