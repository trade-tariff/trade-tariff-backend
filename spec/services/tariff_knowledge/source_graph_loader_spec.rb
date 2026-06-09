RSpec.describe TariffKnowledge::SourceGraphLoader do
  describe '.call' do
    let(:update) { create(:customs_tariff_update, :approved, version: '1.31') }
    let(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }
    let(:heading) { create(:heading, parent: chapter, goods_nomenclature_item_id: '0101000000') }

    before do
      create(:commodity, parent: heading, goods_nomenclature_item_id: '0101210000')
      create(:commodity, parent: heading, goods_nomenclature_item_id: '0101290000')
      create(:chapter, goods_nomenclature_item_id: '0200000000')
      GoodsNomenclatures::TreeNode.refresh!
      TariffKnowledge::DeclarableNodeLoader.call
    end

    it 'builds source, fragment, range, and expansion edges for explicit references only' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers live horses. Chapter 02 is excluded.',
      )

      described_class.call

      source_node = TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.31:01').first
      fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_chapter_note:1.31:01:0001').first
      range_node = TariffKnowledge::Node.by_key('range:heading:0101').first

      expect(source_node).to have_attributes(
        node_type: TariffKnowledge::Node::NOTE_SOURCE,
        title: 'Chapter 01 notes',
      )
      expect(fragment_node).to have_attributes(
        node_type: TariffKnowledge::Node::NOTE_FRAGMENT,
        content: 'Heading 0101 covers live horses.',
      )
      expect(range_node).to have_attributes(
        node_type: TariffKnowledge::Node::RANGE,
        title: 'Heading 0101',
      )

      expect(edge_exists?(source_node, fragment_node, TariffKnowledge::Edge::CONTAINS)).to be(true)
      expect(edge_exists?(fragment_node, range_node, TariffKnowledge::Edge::REFERENCES)).to be(true)

      expanded_codes = TariffKnowledge::Edge
        .by_relationship(TariffKnowledge::Edge::EXPANDS_TO)
        .where(source_node_id: range_node.id)
        .association_join(:target_node)
        .select_map(Sequel[:target_node][:goods_nomenclature_item_id])

      expect(expanded_codes).to contain_exactly('0101210000', '0101290000')
      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::RANGE).map(:key))
        .not_to include('range:chapter:02')
      expect(TariffKnowledge::Edge.by_relationship(TariffKnowledge::Edge::APPLIES_TO).count)
        .to be_zero
    end

    it 'is idempotent' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers live horses.',
      )

      described_class.call

      node_count = TariffKnowledge::Node.count
      edge_count = TariffKnowledge::Edge.count
      described_class.call

      expect(TariffKnowledge::Node.count).to eq(node_count)
      expect(TariffKnowledge::Edge.count).to eq(edge_count)
    end
  end

  def edge_exists?(source_node, target_node, relationship_type)
    TariffKnowledge::Edge.where(
      source_node_id: source_node.id,
      target_node_id: target_node.id,
      relationship_type:,
    ).any?
  end
end
