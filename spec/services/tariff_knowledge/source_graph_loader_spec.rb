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
      expect(edge_exists?(fragment_node, TariffKnowledge::Node.goods_nomenclatures.where(goods_nomenclature_item_id: '0101210000').first, TariffKnowledge::Edge::APPLIES_TO)).to be(true)
      expect(edge_exists?(fragment_node, TariffKnowledge::Node.goods_nomenclatures.where(goods_nomenclature_item_id: '0101290000').first, TariffKnowledge::Edge::APPLIES_TO)).to be(true)
      expect(edge_exists?(fragment_node, range_node, TariffKnowledge::Edge::REFERENCES)).to be(true)

      expanded_codes = TariffKnowledge::Edge
        .by_relationship(TariffKnowledge::Edge::EXPANDS_TO)
        .where(source_node_id: range_node.id)
        .association_join(:target_node)
        .select_map(Sequel[:target_node][:goods_nomenclature_item_id])

      expect(expanded_codes).to contain_exactly('0101210000', '0101290000')
      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::RANGE).map(:key))
        .not_to include('range:chapter:02')
      applied_codes = TariffKnowledge::Edge
        .by_relationship(TariffKnowledge::Edge::APPLIES_TO)
        .where(source_node_id: fragment_node.id)
        .association_join(:target_node)
        .select_map(Sequel[:target_node][:goods_nomenclature_item_id])

      expect(applied_codes).to contain_exactly('0101210000', '0101290000')
    end

    it 'applies chapter note fragments to all declarables in the chapter even without explicit references' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Live animals are classified in this chapter.',
      )

      described_class.call

      fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_chapter_note:1.31:01:0001').first
      applied_codes = TariffKnowledge::Edge
        .by_relationship(TariffKnowledge::Edge::APPLIES_TO)
        .where(source_node_id: fragment_node.id)
        .association_join(:target_node)
        .select_map(Sequel[:target_node][:goods_nomenclature_item_id])

      expect(applied_codes).to contain_exactly('0101210000', '0101290000')
      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::RANGE).count).to be_zero
    end

    it 'keeps list markers attached to the note text they introduce' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: '1. This chapter covers live animals. a. Pure-bred breeding animals are defined here.',
      )

      described_class.call

      fragment_contents = TariffKnowledge::Node
        .note_fragments
        .order(:key)
        .select_map(:content)

      expect(fragment_contents).to eq([
        '1. This chapter covers live animals.',
        'a. Pure-bred breeding animals are defined here.',
      ])
    end

    it 'moves trailing list markers onto the following note text' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: "m. abrasive paper is excluded; n. cellulose wadding is excluded. For these goods: (a). pure-bred animals; ii. other animals; ij. arms. 1. A. The following expressions have the meanings assigned to them.\n\n— the goods comply with the Cereal Seeds Regulations 1974 or\n— it is established that the goods are actually intended for sowing\n6. The duty rate applicable to mixtures falling in Chapter 10 can be found in Part Four.",
      )

      described_class.call

      fragment_contents = TariffKnowledge::Node
        .note_fragments
        .order(:key)
        .select_map(:content)

      expect(fragment_contents).to eq([
        'm. abrasive paper is excluded;',
        'n. cellulose wadding is excluded.',
        'For these goods:',
        '(a). pure-bred animals;',
        'ii. other animals;',
        'ij. arms.',
        '1. A. The following expressions have the meanings assigned to them.',
        "— the goods comply with the Cereal Seeds Regulations 1974 or\n— it is established that the goods are actually intended for sowing",
        '6. The duty rate applicable to mixtures falling in Chapter 10 can be found in Part Four.',
      ])
    end

    it 'keeps dangling numeric tariff references attached to the preceding text' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'The headings do not apply to other preparations of headings 3207, 3208, 3209, 3210, 3212, 3213 and 3215. Subheading 8481 20 takes precedence over all other subheadings of heading 8481. Textile garments means garments of headings 6201 to 6211. Oceanic sharks are of codes 0304 88 29. The goods comply with The Seed Potatoes Regulations 1991. Temperature is measured at 20 C. Classification follows Rule 3.',
      )

      described_class.call

      fragment_contents = TariffKnowledge::Node
        .note_fragments
        .order(:key)
        .select_map(:content)

      expect(fragment_contents).to eq([
        'The headings do not apply to other preparations of headings 3207, 3208, 3209, 3210, 3212, 3213 and 3215.',
        'Subheading 8481 20 takes precedence over all other subheadings of heading 8481.',
        'Textile garments means garments of headings 6201 to 6211.',
        'Oceanic sharks are of codes 0304 88 29.',
        'The goods comply with The Seed Potatoes Regulations 1991.',
        'Temperature is measured at 20 C.',
        'Classification follows Rule 3.',
      ])
    end

    it 'applies chapter note fragments to proxy declarables classified in that chapter' do
      proxy_declarable_node = create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:9880010000',
        goods_nomenclature_sid: 99_001,
        goods_nomenclature_item_id: '9880010000',
        metadata: Sequel.pg_jsonb_wrap('chapter_scope_codes' => %w[01]),
      )
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Live animals are classified in this chapter.',
      )

      described_class.call

      fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_chapter_note:1.31:01:0001').first

      expect(edge_exists?(fragment_node, proxy_declarable_node, TariffKnowledge::Edge::APPLIES_TO)).to be(true)
    end

    it 'applies section note fragments to declarables in the section chapters' do
      section = create(:section, id: 1)
      chapter.add_section(section)
      chapter.save
      create(
        :customs_tariff_section_note,
        :approved,
        customs_tariff_update: update,
        section_id: section.id,
        content: 'Section I covers live animals and animal products.',
      )

      described_class.call

      fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_section_note:1.31:1:0001').first
      applied_codes = TariffKnowledge::Edge
        .by_relationship(TariffKnowledge::Edge::APPLIES_TO)
        .where(source_node_id: fragment_node.id)
        .association_join(:target_node)
        .select_map(Sequel[:target_node][:goods_nomenclature_item_id])

      expect(applied_codes).to contain_exactly('0101210000', '0101290000')
    end

    it 'applies section note fragments to proxy declarables classified in one of the section chapters' do
      section = create(:section, id: 1)
      chapter.add_section(section)
      chapter.save
      proxy_declarable_node = create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:9930240000',
        goods_nomenclature_sid: 99_302,
        goods_nomenclature_item_id: '9930240000',
        metadata: Sequel.pg_jsonb_wrap('chapter_scope_codes' => ('01'..'24').to_a),
      )
      create(
        :customs_tariff_section_note,
        :approved,
        customs_tariff_update: update,
        section_id: section.id,
        content: 'Section I covers live animals and animal products.',
      )

      described_class.call

      fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_section_note:1.31:1:0001').first

      expect(edge_exists?(fragment_node, proxy_declarable_node, TariffKnowledge::Edge::APPLIES_TO)).to be(true)
    end

    it 'loads general rules from an approved update and applies them to every declarable' do
      create(
        :customs_tariff_general_rule,
        :approved,
        customs_tariff_update: update,
        rule_label: '1',
        content: 'Classification shall be determined according to the terms of the headings.',
      )

      described_class.call

      fragment_node = TariffKnowledge::Node.by_key('note_fragment:customs_tariff_general_rule:1.31:1:0001').first
      applied_codes = TariffKnowledge::Edge
        .by_relationship(TariffKnowledge::Edge::APPLIES_TO)
        .where(source_node_id: fragment_node.id)
        .association_join(:target_node)
        .select_map(Sequel[:target_node][:goods_nomenclature_item_id])

      expect(applied_codes).to contain_exactly('0101210000', '0101290000', '0200000000')
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

    it 'loads chapter, section, and general rule source associations from the latest approved update' do
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
        :approved,
        customs_tariff_update: update,
        chapter_id: '02',
        content: 'Heading 0201 is approved.',
      )

      described_class.call

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).select_order_map(:key))
        .to contain_exactly(
          'note_source:customs_tariff_chapter_note:1.31:01',
          'note_source:customs_tariff_chapter_note:1.31:02',
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

    it 'loads notes from the latest current approved update and ignores newer future approved updates' do
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
      create(
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
        content: 'Heading 0101 covers approved future horses.',
      )

      described_class.call

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).select_map(:source_version))
        .to contain_exactly(update.version)
      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.31:01').first.content)
        .to eq('Heading 0101 covers current horses.')
    end

    it 'does not use non-approved updates as the source graph version' do
      rejected_update = create(
        :customs_tariff_update,
        :rejected,
        version: '1.32',
        validity_start_date: 1.month.from_now,
      )
      pending_update = create(
        :customs_tariff_update,
        version: '1.33',
        validity_start_date: 2.months.from_now,
      )
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers approved update horses.',
      )
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: rejected_update,
        chapter_id: '01',
        content: 'Heading 0101 covers rejected update horses.',
      )
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: pending_update,
        chapter_id: '01',
        content: 'Heading 0101 covers pending update horses.',
      )

      described_class.call

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).select_map(:source_version))
        .to contain_exactly(update.version)
      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.31:01').first.content)
        .to eq('Heading 0101 covers approved update horses.')
    end

    it 'does not load non-approved note sources from the selected update' do
      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: update,
        chapter_id: '01',
        content: 'Heading 0101 covers approved source horses.',
      )
      create(
        :customs_tariff_chapter_note,
        customs_tariff_update: update,
        chapter_id: '02',
        content: 'Heading 0201 covers pending source cattle.',
      )
      create(
        :customs_tariff_chapter_note,
        :rejected,
        customs_tariff_update: update,
        chapter_id: '03',
        content: 'Heading 0201 covers rejected source cattle.',
      )

      described_class.call

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).select_order_map(:key))
        .to contain_exactly('note_source:customs_tariff_chapter_note:1.31:01')
    end

    it 'uses the latest approved update even inside an existing TimeMachine date' do
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
      create(
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
        .to contain_exactly(current_update.version)
      expect(TariffKnowledge::Node.by_key('note_source:customs_tariff_chapter_note:1.31:01').first.content)
        .to eq('Heading 0101 covers current horses.')
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
