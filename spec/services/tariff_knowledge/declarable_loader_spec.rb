RSpec.describe TariffKnowledge::DeclarableLoader do
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
  end
end
