RSpec.describe TariffKnowledge::Node do
  describe 'validations' do
    it 'requires a node type and stable key' do
      node = described_class.new

      expect(node).not_to be_valid
      expect(node.errors).to include(:node_type, :key)
    end
  end

  describe 'datasets' do
    it 'looks up graph nodes by stable key and type' do
      goods_node = create(:tariff_knowledge_node, key: 'goods_nomenclature:123')
      create(:tariff_knowledge_node, :note_fragment, key: 'note_fragment:chapter-01:1')

      expect(described_class.by_key('goods_nomenclature:123').first).to eq(goods_node)
      expect(described_class.goods_nomenclatures.all).to contain_exactly(goods_node)
    end
  end

  describe 'versioning' do
    it 'records reviewable graph node changes' do
      node = create(:tariff_knowledge_node, :note_fragment, content: 'first')

      expect { node.update(content: 'updated') }
        .to change(Version.where(item_type: described_class.name), :count).by(1)
    end
  end
end
