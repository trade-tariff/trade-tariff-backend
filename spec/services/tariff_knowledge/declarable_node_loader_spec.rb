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

    it 'does not create goods nomenclature nodes for hidden declarables' do
      commodity = create(
        :commodity,
        parent: heading,
        goods_nomenclature_item_id: '9930240000',
      )
      create(:hidden_goods_nomenclature, goods_nomenclature_item_id: commodity.goods_nomenclature_item_id)
      GoodsNomenclatures::TreeNode.refresh!

      described_class.call

      expect(TariffKnowledge::Node.goods_nomenclatures.where(goods_nomenclature_sid: commodity.goods_nomenclature_sid))
        .to be_empty
    end
  end
end
