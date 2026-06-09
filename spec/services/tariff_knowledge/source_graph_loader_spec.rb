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

    it 'loads approved chapter, section, and general rule source associations from the latest approved update' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers chapter note horses.',
      )
      create(
        :customs_tariff_section_note,
        :approved,
        customs_tariff_update: update,
        section_id: 1,
        content: 'Heading 0101 covers section note horses.',
      )
      create(
        :customs_tariff_general_rule,
        :approved,
        customs_tariff_update: update,
        rule_label: '1',
        content: 'Heading 0101 covers general rule horses.',
      )
      create(
        :customs_tariff_chapter_note,
        customs_tariff_update: update,
        chapter_id: '02',
        content: 'Heading 0201 is pending.',
      )

      described_class.call

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).select_order_map(:key))
        .to contain_exactly(
          'note_source:customs_tariff_chapter_note:1.31:01',
          'note_source:customs_tariff_general_rule:1.31:1',
          'note_source:customs_tariff_section_note:1.31:1',
        )
      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.31:01').first.title)
        .to eq('Chapter 01 notes')
      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_section_note:1.31:1').first.title)
        .to eq('Section 1 notes')
      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_general_rule:1.31:1').first.title)
        .to eq('GIR 1')
    end

    it 'only loads notes from the latest approved update that is actual in TimeMachine' do
      older_update = create(
        :customs_tariff_update,
        :approved,
        version: '1.30',
        validity_start_date: 2.months.ago,
        validity_end_date: 1.month.ago,
      )
      future_update = create(
        :customs_tariff_update,
        :approved,
        version: '1.32',
        validity_start_date: 1.month.from_now,
      )
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: older_update,
        chapter_id: '01',
        content: 'Heading 0101 covers older horses.',
      )
      current_note = create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers current horses.',
      )
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: future_update,
        chapter_id: '01',
        content: 'Heading 0101 covers future horses.',
      )

      described_class.call

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).select_map(:source_version))
        .to contain_exactly(update.version)
      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.31:01').first.content)
        .to eq(current_note.content)
    end

    it 'honours an existing TimeMachine date when choosing the latest approved update and its source associations' do
      old_update = create(
        :customs_tariff_update,
        :approved,
        version: '1.29',
        validity_start_date: Date.new(2020, 1, 1),
        validity_end_date: Date.new(2020, 12, 31),
      )
      current_update = create(
        :customs_tariff_update,
        :approved,
        version: '1.31',
        validity_start_date: Date.new(2021, 1, 1),
      )
      old_note = create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: old_update,
        chapter_id: '01',
        content: 'Heading 0101 covers historical horses.',
      )
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: current_update,
        chapter_id: '01',
        content: 'Heading 0101 covers current horses.',
      )

      TimeMachine.at(Date.new(2020, 6, 1)) { described_class.call }

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).select_map(:source_version))
        .to contain_exactly(old_update.version)
      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.29:01').first.content)
        .to eq(old_note.content)
    end

    it 'sets TimeMachine.now when called outside an existing TimeMachine context' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers current horses.',
      )

      TimeMachine.no_time_machine { described_class.call }

      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.31:01').first)
        .to be_present
    end

    it 'keeps positive references when another clause in the fragment is negated' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers live horses; Chapter 02 is excluded.',
      )

      described_class.call

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::RANGE).select_map(:key))
        .to contain_exactly('range:heading:0101')
    end

    it 'removes stale fragment links when source content has fewer fragments' do
      note = create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers live horses. Heading 0201 covers bovine animals.',
      )

      described_class.call

      note.update(content: 'Heading 0101 covers live horses.')
      described_class.call

      source_node = TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.31:01').first
      current_fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_chapter_note:1.31:01:0001').first
      stale_fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_chapter_note:1.31:01:0002').first

      expect(edge_exists?(source_node, current_fragment_node, TariffKnowledge::Edge::CONTAINS)).to be(true)
      expect(edge_exists?(source_node, stale_fragment_node, TariffKnowledge::Edge::CONTAINS)).to be(false)
    end

    it 'removes stale range references when fragment content changes' do
      note = create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers live horses.',
      )

      described_class.call

      note.update(content: 'Heading 0201 covers bovine animals.')
      described_class.call

      fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_chapter_note:1.31:01:0001').first
      current_range_node = TariffKnowledge::Node.by_key('range:heading:0201').first
      stale_range_node = TariffKnowledge::Node.by_key('range:heading:0101').first

      expect(edge_exists?(fragment_node, current_range_node, TariffKnowledge::Edge::REFERENCES)).to be(true)
      expect(edge_exists?(fragment_node, stale_range_node, TariffKnowledge::Edge::REFERENCES)).to be(false)
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
