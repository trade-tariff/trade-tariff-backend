RSpec.describe RefreshTariffKnowledgeCompressedNotesWorker, type: :worker do
  describe '#perform' do
    let(:worker) { described_class.new }

    it 'logs a skipped message when the fingerprint is unchanged' do
      result = TariffKnowledge::CompressedNoteRefresh::Result.new(
        goods_nomenclature_count: 0, expired_note_count: 0, skipped: true,
      )
      allow(TariffKnowledge::CompressedNoteRefresh).to receive(:call).and_return(result)

      expect(worker.logger).to receive(:info).with(/skipped/)

      worker.perform
    end

    it 'logs a completion message with counts when the full run completes' do
      result = TariffKnowledge::CompressedNoteRefresh::Result.new(
        goods_nomenclature_count: 42, expired_note_count: 3, skipped: false,
      )
      allow(TariffKnowledge::CompressedNoteRefresh).to receive(:call).and_return(result)

      expect(worker.logger).to receive(:info).with(/42.*3|3.*42|complete/)

      worker.perform
    end
  end

  it 'uses the sync queue' do
    expect(described_class.sidekiq_options['queue']).to eq(:sync)
  end

  it 'does not retry failures' do
    expect(described_class.sidekiq_options['retry']).to be(false)
  end
end
