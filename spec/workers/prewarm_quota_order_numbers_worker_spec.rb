RSpec.describe PrewarmQuotaOrderNumbersWorker do
  subject(:worker) { described_class.new }

  describe 'sidekiq options' do
    it 'caps retries below Sidekiq default' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end

  describe '#perform' do
    it 'calls the CachedQuotaOrderNumberService' do
      allow(CachedQuotaOrderNumberService).to receive(:new).and_call_original

      worker.perform

      expect(CachedQuotaOrderNumberService).to have_received(:new)
    end

    it 'uses the TimeMachine' do
      allow(TimeMachine).to receive(:now).and_call_original

      worker.perform

      expect(TimeMachine).to have_received(:now)
    end
  end
end
