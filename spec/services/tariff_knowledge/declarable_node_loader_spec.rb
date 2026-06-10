RSpec.describe TariffKnowledge::DeclarableNodeLoader do
  describe '.call' do
    let(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }
    let(:heading) { create(:heading, parent: chapter, goods_nomenclature_item_id: '0101000000') }

    before do
      create(:commodity, parent: heading, goods_nomenclature_item_id: '0101210000')
      create(:commodity, parent: heading, goods_nomenclature_item_id: '0101290000')
      GoodsNomenclatures::TreeNode.refresh!
    end

    it 'creates a goods nomenclature node for each current declarable' do
      described_class.call

      expect(TariffKnowledge::Node.goods_nomenclatures.map(:goods_nomenclature_item_id))
        .to include('0101210000', '0101290000')
    end

    it 'is idempotent' do
      described_class.call

      expect { described_class.call }
        .not_to change(TariffKnowledge::Node.goods_nomenclatures, :count)
    end

    it 'updates existing declarable nodes when tariff metadata changes' do
      commodity = Commodity.where(goods_nomenclature_item_id: '0101210000').first
      create(
        :tariff_knowledge_node,
        key: "goods_nomenclature:#{commodity.goods_nomenclature_sid}",
        goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        goods_nomenclature_item_id: 'stale-code',
      )

      described_class.call

      node = TariffKnowledge::Node.goods_nomenclatures
                                  .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
                                  .first
      expect(node.goods_nomenclature_item_id).to eq('0101210000')
    end

    it 'stores explicit chapter scope metadata for proxy declarables' do
      chapter = create(
        :chapter,
        :with_description,
        goods_nomenclature_item_id: '9900000000',
        description: 'Special combined nomenclature codes',
      )
      heading = create(
        :heading,
        :with_description,
        parent: chapter,
        goods_nomenclature_item_id: '9930000000',
        description: 'Goods from CN chapters 1 to 24',
      )
      commodity = create(
        :commodity,
        :with_description,
        parent: heading,
        goods_nomenclature_item_id: '9930240000',
        description: 'Other',
      )
      GoodsNomenclatures::TreeNode.refresh!

      described_class.call

      node = TariffKnowledge::Node.goods_nomenclatures
                                  .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
                                  .first
      expect(node.content).to be_nil
      expect(node.metadata.to_hash).to include('chapter_scope_codes' => ('01'..'24').to_a)
    end
  end
end
