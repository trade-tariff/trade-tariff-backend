RSpec.describe TariffKnowledge::CompressedNoteRefresh do
  describe '.call' do
    before do
      create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:123',
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
      )
      create(
        :tariff_knowledge_compressed_note,
        goods_nomenclature_sid: 999,
        goods_nomenclature_item_id: '9999999999',
        expired: false,
      )

      allow(TariffKnowledge::DeclarableNodeLoader).to receive(:call)
      allow(TariffKnowledge::SourceGraphLoader).to receive(:call)
      allow(TariffKnowledge::CompressedNoteGenerator).to receive(:call)
    end

    it 'regenerates compressed notes for current declarables and expires old notes' do
      result = described_class.call

      expect(TariffKnowledge::DeclarableNodeLoader).to have_received(:call).ordered
      expect(TariffKnowledge::SourceGraphLoader).to have_received(:call).ordered
      expect(TariffKnowledge::CompressedNoteGenerator)
        .to have_received(:call).with(goods_nomenclature_sids: [123]).ordered
      expect(TariffKnowledge::CompressedNote[999].expired).to be(true)
      expect(result).to have_attributes(
        goods_nomenclature_count: 1,
        expired_note_count: 1,
      )
    end
  end
end
