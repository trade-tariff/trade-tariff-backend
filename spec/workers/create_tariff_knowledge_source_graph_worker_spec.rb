RSpec.describe CreateTariffKnowledgeSourceGraphWorker, type: :worker do
  describe '#perform' do
    it 'delegates source graph loading' do
      allow(TariffKnowledge::SourceGraphLoader).to receive(:call)

      described_class.new.perform

      expect(TariffKnowledge::SourceGraphLoader).to have_received(:call)
    end
  end

  it 'uses the sync queue' do
    expect(described_class.sidekiq_options['queue']).to eq(:sync)
  end

  it 'does not retry failures' do
    expect(described_class.sidekiq_options['retry']).to be(false)
  end
end
