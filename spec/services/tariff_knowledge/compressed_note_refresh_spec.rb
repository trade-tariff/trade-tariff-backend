RSpec.describe TariffKnowledge::CompressedNoteRefresh do
  describe '.call' do
    let(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }
    let(:heading) { create(:heading, parent: chapter, goods_nomenclature_item_id: '0101000000') }

    before do
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
      create(:commodity, parent: heading, goods_nomenclature_sid: 123, goods_nomenclature_item_id: '0101210000')
      create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:456',
        goods_nomenclature_sid: 456,
        goods_nomenclature_item_id: '0101290000',
      )
      GoodsNomenclatures::TreeNode.refresh!

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

    it 'processes current declarables in batches' do
      stub_const("#{described_class}::BATCH_SIZE", 1)
      create(:commodity, parent: heading, goods_nomenclature_sid: 123, goods_nomenclature_item_id: '0101210000')
      create(:commodity, parent: heading, goods_nomenclature_sid: 124, goods_nomenclature_item_id: '0101290000')
      GoodsNomenclatures::TreeNode.refresh!

      described_class.call

      expect(TariffKnowledge::CompressedNoteGenerator)
        .to have_received(:call).with(goods_nomenclature_sids: [123]).ordered
      expect(TariffKnowledge::CompressedNoteGenerator)
        .to have_received(:call).with(goods_nomenclature_sids: [124]).ordered
    end

    it 'expires all unexpired notes when there are no current declarables' do
      described_class.call

      expect(TariffKnowledge::CompressedNote[999].expired).to be(true)
    end
  end
end
