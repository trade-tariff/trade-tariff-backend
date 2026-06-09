RSpec.describe GenerateTariffKnowledgeCompressedNotesWorker, type: :worker do
  describe '#perform' do
    it 'delegates compressed note generation for the supplied goods nomenclature sids' do
      allow(TariffKnowledge::CompressedNoteGenerator).to receive(:call)

      described_class.new.perform([123, 456])

      expect(TariffKnowledge::CompressedNoteGenerator)
        .to have_received(:call).with(goods_nomenclature_sids: [123, 456])
    end
  end

  it 'uses the sync queue' do
    expect(described_class.sidekiq_options['queue']).to eq(:sync)
  end

  it 'does not retry failures' do
    expect(described_class.sidekiq_options['retry']).to be(false)
  end
end
