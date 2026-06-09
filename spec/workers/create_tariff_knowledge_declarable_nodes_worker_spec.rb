RSpec.describe CreateTariffKnowledgeDeclarableNodesWorker, type: :worker do
  describe '#perform' do
    it 'loads declarable goods nomenclature graph nodes' do
      allow(TariffKnowledge::DeclarableNodeLoader).to receive(:call)

      described_class.new.perform

      expect(TariffKnowledge::DeclarableNodeLoader).to have_received(:call)
    end
  end

  describe 'sidekiq options' do
    it 'uses the sync queue' do
      expect(described_class.sidekiq_options['queue']).to eq(:sync)
    end

    it 'disables retries' do
      expect(described_class.sidekiq_options['retry']).to be(false)
    end
  end
end
