RSpec.describe ReindexModelsWorker, type: :worker do
  describe '#perform' do
    let(:perform) { described_class.new.perform }

    before do
      create :commodity

      allow(BuildIndexPageWorker).to receive(:perform_async).and_call_original
      allow(TradeTariffBackend).to receive(:reindex).and_call_original

      perform
    end

    it 'calls reindex' do
      expect(TradeTariffBackend).to have_received(:reindex)
    end

    it 'queues workers to build the index' do
      expect(BuildIndexPageWorker).to have_received(:perform_async).exactly(2).times
    end
  end
end
