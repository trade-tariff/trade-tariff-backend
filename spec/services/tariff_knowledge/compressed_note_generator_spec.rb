RSpec.describe TariffKnowledge::CompressedNoteGenerator do
  describe '.call' do
    let(:declarable_node) do
      create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:123',
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
        content: '0100000000: Live animals > 0101000000: Live horses, asses, mules and hinnies > 0101210000: Pure-bred breeding animals',
      )
    end
    let(:range_node) do
      create(
        :tariff_knowledge_node,
        node_type: TariffKnowledge::Node::RANGE,
        key: 'range:heading:0101',
        title: 'Heading 0101',
        goods_nomenclature_sid: nil,
        goods_nomenclature_item_id: nil,
        producline_suffix: nil,
        goods_nomenclature_type: nil,
        metadata: Sequel.pg_jsonb_wrap({ 'range_type' => 'heading', 'code' => '0101' }),
      )
    end
    let(:source_node) do
      create(
        :tariff_knowledge_node,
        node_type: TariffKnowledge::Node::NOTE_SOURCE,
        key: 'note_source:customs_tariff_chapter_note:1.31:01',
        title: 'Chapter 01 notes',
        content: "1. This chapter includes:\n\nHeading 0101 covers live horses.",
        goods_nomenclature_sid: nil,
        goods_nomenclature_item_id: nil,
        producline_suffix: nil,
        goods_nomenclature_type: nil,
      )
    end
    let(:lead_in_fragment_node) do
      create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:customs_tariff_chapter_note:1.31:01:0001',
        title: 'Chapter 01 notes fragment 1',
        content: '1. This chapter includes:',
      )
    end
    let(:fragment_node) do
      create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:customs_tariff_chapter_note:1.31:01:0002',
        title: 'Chapter 01 notes fragment 2',
        content: 'Heading 0101 covers live horses.',
      )
    end
    let(:note_block_node) do
      create(
        :tariff_knowledge_node,
        node_type: TariffKnowledge::Node::NOTE_BLOCK,
        key: 'note_block:customs_tariff_chapter_note:1.31:01:1:a',
        title: 'pure-bred breeding animals',
        content: 'pure-bred breeding animals means animals certified as breeding stock.',
        source_type: 'customs_tariff_chapter_note',
        source_id: '01',
        source_version: '1.31',
        metadata: Sequel.pg_jsonb_wrap(
          'block_type' => 'definition',
          'term' => 'pure-bred breeding animals',
          'path' => %w[1 a],
        ),
        goods_nomenclature_sid: nil,
        goods_nomenclature_item_id: nil,
        producline_suffix: nil,
        goods_nomenclature_type: nil,
      )
    end

    before do
      create(
        :tariff_knowledge_edge,
        source_node:,
        target_node: lead_in_fragment_node,
        relationship_type: TariffKnowledge::Edge::CONTAINS,
      )
      create(
        :tariff_knowledge_edge,
        source_node:,
        target_node: fragment_node,
        relationship_type: TariffKnowledge::Edge::CONTAINS,
      )
      create(
        :tariff_knowledge_edge,
        source_node: fragment_node,
        target_node: range_node,
        relationship_type: TariffKnowledge::Edge::REFERENCES,
      )
      create(
        :tariff_knowledge_edge,
        source_node: range_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::EXPANDS_TO,
      )
      create(
        :tariff_knowledge_edge,
        source_node: fragment_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )
    end

    it 'creates compressed notes from directly applicable source-evidenced graph fragments' do
      described_class.call(goods_nomenclature_sids: [123])

      note = TariffKnowledge::CompressedNote[123]
      expect(note).to have_attributes(
        goods_nomenclature_item_id: '0101210000',
        content: "Chapter 01 notes fragment 2\nHeading 0101 covers live horses.",
        needs_review: false,
        approved: false,
        stale: false,
      )
      expect(note.metadata.to_hash).to include(
        'source_node_keys' => ['note_fragment:customs_tariff_chapter_note:1.31:01:0002'],
        'range_node_keys' => ['range:heading:0101'],
      )
      expect(note.metadata.to_hash['evidence'].size).to eq(1)
      evidence = note.metadata.to_hash['evidence'].first
      expect(evidence).to include(
        'source_node_key' => 'note_fragment:customs_tariff_chapter_note:1.31:01:0002',
        'source_type' => 'customs_tariff_chapter_note',
        'source_id' => '01',
        'source_version' => '1.31',
        'source_title' => 'Chapter 01 notes fragment 2',
        'parent_source_node_key' => 'note_source:customs_tariff_chapter_note:1.31:01',
        'parent_source_title' => 'Chapter 01 notes',
        'source_context' => '1. This chapter includes: Heading 0101 covers live horses.',
        'context_type' => 'inclusion',
        'range_node_key' => 'range:heading:0101',
        'range_title' => 'Heading 0101',
      )
      expect(evidence['relationships']).to contain_exactly(
        TariffKnowledge::Edge::REFERENCES,
        TariffKnowledge::Edge::EXPANDS_TO,
        TariffKnowledge::Edge::APPLIES_TO,
      )
      expect(note.context_hash).to eq(Digest::SHA256.hexdigest(note.content))
    end

    it 'stores coherent note block evidence for definition blocks' do
      create(
        :tariff_knowledge_edge,
        source_node: note_block_node,
        target_node: lead_in_fragment_node,
        relationship_type: TariffKnowledge::Edge::CONTAINS,
      )
      create(
        :tariff_knowledge_edge,
        source_node: note_block_node,
        target_node: fragment_node,
        relationship_type: TariffKnowledge::Edge::CONTAINS,
      )
      create(
        :tariff_knowledge_edge,
        source_node: note_block_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )

      described_class.call(goods_nomenclature_sids: [123])

      note = TariffKnowledge::CompressedNote[123]
      expect(note.metadata.to_hash['evidence_blocks']).to contain_exactly(
        include(
          'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:01:1:a',
          'source_type' => 'customs_tariff_chapter_note',
          'source_id' => '01',
          'source_version' => '1.31',
          'source_title' => 'pure-bred breeding animals',
          'source_context' => 'pure-bred breeding animals means animals certified as breeding stock.',
          'block_type' => 'definition',
          'term' => 'pure-bred breeding animals',
          'path' => %w[1 a],
          'fragment_node_keys' => [
            'note_fragment:customs_tariff_chapter_note:1.31:01:0001',
            'note_fragment:customs_tariff_chapter_note:1.31:01:0002',
          ],
        ),
      )
      expect(note.metadata.to_hash['evidence']).to be_present
    end

    it 'generates from block-only evidence' do
      TariffKnowledge::Edge
        .where(
          source_node_id: fragment_node.id,
          target_node_id: declarable_node.id,
          relationship_type: TariffKnowledge::Edge::APPLIES_TO,
        )
        .delete
      TariffKnowledge::Edge
        .where(
          source_node_id: fragment_node.id,
          target_node_id: range_node.id,
          relationship_type: TariffKnowledge::Edge::REFERENCES,
        )
        .delete
      create(
        :tariff_knowledge_edge,
        source_node: note_block_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )

      described_class.call(goods_nomenclature_sids: [123])

      note = TariffKnowledge::CompressedNote[123]
      expect(note).to have_attributes(stale: false)
      expect(note.content).to include('pure-bred breeding animals')
      expect(note.content).to include('animals certified as breeding stock')
      expect(note.metadata.to_hash).to include(
        'source_node_keys' => [],
        'range_node_keys' => [],
        'evidence' => [],
      )
      expect(note.metadata.to_hash['evidence_blocks'].first['fragment_node_keys']).to eq([])
    end

    it 'ignores old source version block evidence' do
      create(
        :customs_tariff_update,
        :approved,
        version: '1.30',
        validity_start_date: 2.months.ago,
        validity_end_date: 1.month.ago,
      )
      create(
        :customs_tariff_update,
        version: '1.31',
        validity_start_date: 1.day.ago,
      )
      old_block_node = create(
        :tariff_knowledge_node,
        node_type: TariffKnowledge::Node::NOTE_BLOCK,
        key: 'note_block:customs_tariff_chapter_note:1.30:01:1:a',
        title: 'Old definition block',
        content: 'Old version block evidence should not be used.',
        source_type: 'customs_tariff_chapter_note',
        source_id: '01',
        source_version: '1.30',
        goods_nomenclature_sid: nil,
        goods_nomenclature_item_id: nil,
        producline_suffix: nil,
        goods_nomenclature_type: nil,
      )
      create(
        :tariff_knowledge_edge,
        source_node: old_block_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )
      create(
        :tariff_knowledge_edge,
        source_node: note_block_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )

      described_class.call(goods_nomenclature_sids: [123])

      expect(TariffKnowledge::CompressedNote[123].metadata.to_hash['evidence_blocks'])
        .to contain_exactly(include('source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:01:1:a'))
    end

    it 'ignores old source version fragments contained by current block evidence' do
      create(
        :customs_tariff_update,
        :approved,
        version: '1.30',
        validity_start_date: 2.months.ago,
        validity_end_date: 1.month.ago,
      )
      create(
        :customs_tariff_update,
        version: '1.31',
        validity_start_date: 1.day.ago,
      )
      old_fragment_node = create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:customs_tariff_chapter_note:1.30:01:0001',
        title: 'Old Chapter 01 notes fragment 1',
        content: 'Old version contained evidence should not be used.',
        source_type: 'customs_tariff_chapter_note',
        source_id: '01',
        source_version: '1.30',
      )
      create(
        :tariff_knowledge_edge,
        source_node: note_block_node,
        target_node: old_fragment_node,
        relationship_type: TariffKnowledge::Edge::CONTAINS,
      )
      create(
        :tariff_knowledge_edge,
        source_node: note_block_node,
        target_node: fragment_node,
        relationship_type: TariffKnowledge::Edge::CONTAINS,
      )
      create(
        :tariff_knowledge_edge,
        source_node: note_block_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )

      described_class.call(goods_nomenclature_sids: [123])

      evidence_block = TariffKnowledge::CompressedNote[123].metadata.to_hash['evidence_blocks'].first
      expect(evidence_block['fragment_node_keys']).to eq(['note_fragment:customs_tariff_chapter_note:1.31:01:0002'])
    end

    it 'preloads block fragment evidence for the requested goods nomenclatures' do
      TariffKnowledge::Edge
        .where(
          source_node_id: fragment_node.id,
          target_node_id: declarable_node.id,
          relationship_type: TariffKnowledge::Edge::APPLIES_TO,
        )
        .delete
      TariffKnowledge::Edge
        .where(
          source_node_id: fragment_node.id,
          target_node_id: range_node.id,
          relationship_type: TariffKnowledge::Edge::REFERENCES,
        )
        .delete
      TariffKnowledge::Edge
        .where(
          source_node_id: range_node.id,
          target_node_id: declarable_node.id,
          relationship_type: TariffKnowledge::Edge::EXPANDS_TO,
        )
        .delete
      second_declarable_node = create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:456',
        goods_nomenclature_sid: 456,
        goods_nomenclature_item_id: '0101290000',
      )
      third_declarable_node = create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:789',
        goods_nomenclature_sid: 789,
        goods_nomenclature_item_id: '0101300000',
      )
      block_nodes = [declarable_node, second_declarable_node, third_declarable_node].map.with_index do |node, index|
        block_node = create(
          :tariff_knowledge_node,
          node_type: TariffKnowledge::Node::NOTE_BLOCK,
          key: "note_block:customs_tariff_chapter_note:1.31:01:#{index + 1}:a",
          title: "Definition block #{index + 1}",
          content: "Block #{index + 1} context.",
          source_type: 'customs_tariff_chapter_note',
          source_id: '01',
          source_version: '1.31',
          goods_nomenclature_sid: nil,
          goods_nomenclature_item_id: nil,
          producline_suffix: nil,
          goods_nomenclature_type: nil,
        )
        create(
          :tariff_knowledge_edge,
          source_node: block_node,
          target_node: fragment_node,
          relationship_type: TariffKnowledge::Edge::CONTAINS,
        )
        create(
          :tariff_knowledge_edge,
          source_node: block_node,
          target_node: node,
          relationship_type: TariffKnowledge::Edge::APPLIES_TO,
        )
        block_node
      end

      queries = sql_queries do
        described_class.call(goods_nomenclature_sids: [123, 456, 789])
      end

      contains_edge_queries = queries.grep(/FROM "tariff_knowledge_edges".*"relationship_type" = 'contains'/)
      expect(contains_edge_queries.size).to eq(1)
      expect(block_nodes.map(&:key)).to match_array(
        [123, 456, 789].map { |sid| TariffKnowledge::CompressedNote[sid].metadata.to_hash.dig('evidence_blocks', 0, 'source_node_key') },
      )
    end

    it 'includes fragments that directly apply to the declarable without an explicit range reference' do
      scoped_fragment_node = create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:customs_tariff_chapter_note:1.31:01:0003',
        title: 'Chapter 01 notes fragment 3',
        content: 'Live animals are classified in this chapter.',
      )
      create(
        :tariff_knowledge_edge,
        source_node: scoped_fragment_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )

      described_class.call(goods_nomenclature_sids: [123])

      note = TariffKnowledge::CompressedNote[123]
      expect(note.content).to include('Chapter 01 notes fragment 2')
      expect(note.content).to include('Heading 0101 covers live horses.')
      expect(note.content).to include('Chapter 01 notes fragment 3')
      expect(note.content).to include('Live animals are classified in this chapter.')
      expect(note.metadata.to_hash).to include(
        'source_node_keys' => [
          'note_fragment:customs_tariff_chapter_note:1.31:01:0002',
          'note_fragment:customs_tariff_chapter_note:1.31:01:0003',
        ],
      )
      direct_evidence = note.metadata.to_hash['evidence'].find do |evidence|
        evidence['source_node_key'] == 'note_fragment:customs_tariff_chapter_note:1.31:01:0003'
      end
      expect(direct_evidence).to include(
        'range_node_key' => nil,
        'relationships' => [TariffKnowledge::Edge::APPLIES_TO],
      )
    end

    it 'summarises directly applicable general rules while retaining provenance' do
      general_rule_fragment_node = create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:customs_tariff_general_rule:1.31:1:0001',
        title: 'General Interpretive Rule 1 fragment 1',
        content: 'Classification shall be determined according to the terms of the headings and any relative section or chapter notes.',
        source_type: 'customs_tariff_general_rule',
        source_id: '1',
      )
      create(
        :tariff_knowledge_edge,
        source_node: general_rule_fragment_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )

      described_class.call(goods_nomenclature_sids: [123])

      note = TariffKnowledge::CompressedNote[123]
      expect(note.content).to include('Chapter 01 notes fragment 2')
      expect(note.content).to include('Heading 0101 covers live horses.')
      expect(note.content).to include('General Interpretive Rules 1 apply when classifying goods.')
      expect(note.content).not_to include('Commodity context')
      expect(note.content).not_to include('0101210000: Pure-bred breeding animals')
      expect(note.content).not_to include('Classification shall be determined according to the terms of the headings')
      expect(note.metadata.to_hash).to include(
        'source_node_keys' => [
          'note_fragment:customs_tariff_chapter_note:1.31:01:0002',
          'note_fragment:customs_tariff_general_rule:1.31:1:0001',
        ],
      )
    end

    it 'does not include referenced fragments that do not directly apply to the declarable' do
      TariffKnowledge::Edge
        .where(
          source_node_id: fragment_node.id,
          target_node_id: range_node.id,
          relationship_type: TariffKnowledge::Edge::REFERENCES,
        )
        .delete
      TariffKnowledge::Edge
        .where(
          source_node_id: range_node.id,
          target_node_id: declarable_node.id,
          relationship_type: TariffKnowledge::Edge::EXPANDS_TO,
        )
        .delete
      TariffKnowledge::Edge
        .where(
          source_node_id: fragment_node.id,
          target_node_id: declarable_node.id,
          relationship_type: TariffKnowledge::Edge::APPLIES_TO,
        )
        .delete
      non_applicable_fragment_node = create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:customs_tariff_section_note:1.31:16:0001',
        title: 'Section XVI notes fragment 1',
        content: 'This section does not cover articles of chapter 39.',
      )
      create(
        :tariff_knowledge_edge,
        source_node: non_applicable_fragment_node,
        target_node: range_node,
        relationship_type: TariffKnowledge::Edge::REFERENCES,
      )
      create(
        :tariff_knowledge_edge,
        source_node: range_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::EXPANDS_TO,
      )

      described_class.call(goods_nomenclature_sids: [123])

      expect(TariffKnowledge::CompressedNote[123]).to be_nil
    end

    it 'updates generated notes when the graph context changes' do
      described_class.call(goods_nomenclature_sids: [123])
      fragment_node.update(content: 'Heading 0101 covers live horses and asses.')

      described_class.call(goods_nomenclature_sids: [123])

      expect(TariffKnowledge::CompressedNote[123].content)
        .to include('horses and asses')
    end

    it 'does not overwrite manually edited notes' do
      create(
        :tariff_knowledge_compressed_note,
        goods_nomenclature_sid: 123,
        content: 'Reviewed human content',
        manually_edited: true,
        approved: true,
      )

      described_class.call(goods_nomenclature_sids: [123])

      expect(TariffKnowledge::CompressedNote[123].content)
        .to eq('Reviewed human content')
    end

    it 'marks manually edited notes stale when graph context changes' do
      create(
        :tariff_knowledge_compressed_note,
        goods_nomenclature_sid: 123,
        content: 'Reviewed human content',
        context_hash: Digest::SHA256.hexdigest('Reviewed human content'),
        manually_edited: true,
        approved: true,
        stale: false,
      )

      described_class.call(goods_nomenclature_sids: [123])

      note = TariffKnowledge::CompressedNote[123]
      expect(note).to have_attributes(
        content: 'Reviewed human content',
        stale: true,
      )
    end

    it 'marks existing notes stale when evidence disappears' do
      create(
        :tariff_knowledge_compressed_note,
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
        content: 'Old generated context',
        stale: false,
        expired: false,
        needs_review: false,
      )
      TariffKnowledge::Edge.where(target_node_id: declarable_node.id).delete

      described_class.call(goods_nomenclature_sids: [123])

      expect(TariffKnowledge::CompressedNote[123]).to have_attributes(stale: true)
      expect(TariffKnowledge::CompressedNote.usable_for_search.by_sids([123]).all).to be_empty
    end

    it 'ignores fragments from old source versions based on latest non-failed update' do
      create(
        :customs_tariff_update,
        :approved,
        version: '1.30',
        validity_start_date: 2.months.ago,
        validity_end_date: 1.month.ago,
      )
      create(
        :customs_tariff_update,
        version: '1.31',
        validity_start_date: 1.day.ago,
      )
      old_fragment_node = create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:customs_tariff_chapter_note:1.30:01:0001',
        title: 'Old Chapter 01 notes fragment 1',
        content: 'Old version evidence should not be used.',
        source_version: '1.30',
      )
      create(
        :tariff_knowledge_edge,
        source_node: old_fragment_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )

      described_class.call(goods_nomenclature_sids: [123])

      expect(TariffKnowledge::CompressedNote[123].content)
        .not_to include('Old version evidence')
    end

    it 'preloads graph evidence for the requested goods nomenclatures' do
      second_declarable_node = create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:456',
        goods_nomenclature_sid: 456,
        goods_nomenclature_item_id: '0101290000',
      )
      create(
        :tariff_knowledge_edge,
        source_node: range_node,
        target_node: second_declarable_node,
        relationship_type: TariffKnowledge::Edge::EXPANDS_TO,
      )
      create(
        :tariff_knowledge_edge,
        source_node: fragment_node,
        target_node: second_declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )

      queries = sql_queries do
        described_class.call(goods_nomenclature_sids: [123, 456])
      end

      expect(queries.grep(/FROM "tariff_knowledge_edges"/).size).to be <= 5
    end

    it 'uses source note context to identify exclusion evidence' do
      source_node.update(content: "1. This chapter does not cover:\n\nHeading 0101 covers live horses.")
      lead_in_fragment_node.update(content: '1. This chapter does not cover:')

      described_class.call(goods_nomenclature_sids: [123])

      evidence = TariffKnowledge::CompressedNote[123].metadata['evidence'].first
      expect(evidence['source_context']).to eq('1. This chapter does not cover: Heading 0101 covers live horses.')
      expect(evidence['context_type']).to eq('exclusion')
    end

    it 'derives source context from graph fragment order when content has been merged' do
      source_node.update(content: "1. This chapter includes:\n\nii.\n\nHeading 0101 covers live horses.")
      fragment_node.update(content: 'ii. Heading 0101 covers live horses.')

      described_class.call(goods_nomenclature_sids: [123])

      evidence = TariffKnowledge::CompressedNote[123].metadata['evidence'].first
      expect(evidence['source_context']).to eq('1. This chapter includes: ii. Heading 0101 covers live horses.')
      expect(evidence['context_type']).to eq('inclusion')
    end
  end

  def sql_queries
    queries = []
    logger = Logger.new(StringIO.new)
    logger.formatter = proc do |_severity, _datetime, _progname, message|
      queries << message
      nil
    end

    Sequel::Model.db.loggers << logger
    yield
    queries
  ensure
    Sequel::Model.db.loggers.delete(logger)
  end
end
