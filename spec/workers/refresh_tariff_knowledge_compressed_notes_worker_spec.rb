RSpec.describe RefreshTariffKnowledgeCompressedNotesWorker, type: :worker do
  describe '#perform' do
    it 'delegates compressed note refresh' do
      allow(TariffKnowledge::CompressedNoteRefresh).to receive(:call)

      described_class.new.perform

      expect(TariffKnowledge::CompressedNoteRefresh).to have_received(:call)
    end
  end

  it 'uses the sync queue' do
    expect(described_class.sidekiq_options['queue']).to eq(:sync)
  end

  it 'does not retry failures' do
    expect(described_class.sidekiq_options['retry']).to be(false)
  end
end
