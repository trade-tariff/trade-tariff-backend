RSpec.describe TariffKnowledge::CompressedNoteGenerator do
  describe '.call' do
    let(:declarable_node) do
      create(
        :tariff_knowledge_node,
        key: 'goods_nomenclature:123',
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
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
      )
    end
    let(:fragment_node) do
      create(
        :tariff_knowledge_node,
        :note_fragment,
        key: 'note_fragment:customs_tariff_chapter_note:1.31:01:0001',
        title: 'Chapter 01 notes fragment 1',
        content: 'Heading 0101 covers live horses.',
      )
    end

    before do
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
    end

    it 'creates reviewable compressed notes from source-evidenced graph fragments' do
      described_class.call(goods_nomenclature_sids: [123])

      note = TariffKnowledge::CompressedNote[123]
      expect(note).to have_attributes(
        goods_nomenclature_item_id: '0101210000',
        content: "Chapter 01 notes fragment 1\nHeading 0101 covers live horses.",
        needs_review: true,
        approved: false,
        stale: false,
      )
      expect(note.metadata.to_hash).to include(
        'source_node_keys' => ['note_fragment:customs_tariff_chapter_note:1.31:01:0001'],
        'range_node_keys' => ['range:heading:0101'],
      )
      expect(note.context_hash).to eq(Digest::SHA256.hexdigest(note.content))
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
  end
end
