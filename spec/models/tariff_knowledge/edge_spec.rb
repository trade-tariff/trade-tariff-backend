RSpec.describe TariffKnowledge::Edge do
  describe 'associations' do
    it 'connects a source graph node to a target graph node' do
      edge = create(:tariff_knowledge_edge)

      expect(edge.source_node.node_type).to eq(TariffKnowledge::Node::NOTE_FRAGMENT)
      expect(edge.target_node.node_type).to eq(TariffKnowledge::Node::GOODS_NOMENCLATURE)
    end
  end

  describe 'datasets' do
    it 'finds relationships by target and type' do
      edge = create(:tariff_knowledge_edge, relationship_type: described_class::APPLIES_TO)
      create(:tariff_knowledge_edge, relationship_type: described_class::REFERENCES)

      expect(described_class.by_target(edge.target_node).all).to contain_exactly(edge)
      expect(described_class.by_relationship(described_class::APPLIES_TO).all).to contain_exactly(edge)
    end
  end
end
