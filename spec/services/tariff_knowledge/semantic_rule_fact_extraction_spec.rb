RSpec.describe TariffKnowledge::SemanticRuleFactExtraction do
  describe '.call' do
    let(:referenced_fragment) do
      create(
        :tariff_knowledge_node,
        :note_fragment,
        content: 'Heading 0101 covers live horses.',
        source_type: 'customs_tariff_chapter_note',
        source_id: '01',
      )
    end
    let(:unreferenced_fragment) do
      create(
        :tariff_knowledge_node,
        :note_fragment,
        content: 'Generic note text.',
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

    before do
      create(
        :tariff_knowledge_edge,
        source_node: referenced_fragment,
        target_node: range_node,
        relationship_type: TariffKnowledge::Edge::REFERENCES,
      )
      allow(TariffKnowledge::SemanticRuleFactExtractor).to receive(:call).and_return([])
    end

    it 'extracts facts only for fragments with deterministic references' do
      result = described_class.call(fragment_node_ids: [referenced_fragment.id, unreferenced_fragment.id])

      expect(result).to have_attributes(fragment_count: 1, fact_count: 0)
      expect(TariffKnowledge::SemanticRuleFactExtractor)
        .to have_received(:call)
        .with(
          fragment_node: referenced_fragment,
          source_reference: { 'type' => 'chapter', 'code' => '01' },
          candidate_references: [{ 'type' => 'heading', 'code' => '0101' }],
        )
    end

    it 'passes section note source references to the extractor' do
      referenced_fragment.update(
        source_type: 'customs_tariff_section_note',
        source_id: '1',
      )

      described_class.call(fragment_node_ids: [referenced_fragment.id])

      expect(TariffKnowledge::SemanticRuleFactExtractor)
        .to have_received(:call)
        .with(
          fragment_node: referenced_fragment,
          source_reference: { 'type' => 'section', 'code' => '1' },
          candidate_references: [{ 'type' => 'heading', 'code' => '0101' }],
        )
    end

    it 'skips fragments from stale source versions when a current update exists' do
      create(:customs_tariff_update, version: '1.30', validity_start_date: 2.days.ago)
      create(:customs_tariff_update, version: '1.31', validity_start_date: 1.day.ago)
      referenced_fragment.update(source_version: '1.30')

      result = described_class.call(fragment_node_ids: [referenced_fragment.id])

      expect(result).to have_attributes(fragment_count: 0, fact_count: 0)
      expect(TariffKnowledge::SemanticRuleFactExtractor).not_to have_received(:call)
    end

    it 'regenerates compressed notes for goods affected by extracted fragments' do
      declarable_node = create(
        :tariff_knowledge_node,
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
      )
      create(
        :tariff_knowledge_edge,
        source_node: referenced_fragment,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )
      allow(TariffKnowledge::SemanticRuleFactExtractor)
        .to receive(:call)
        .and_return([{ 'source_span' => 'Heading 0101 covers live horses.' }])
      allow(TariffKnowledge::CompressedNoteGenerator).to receive(:call)

      result = described_class.call(fragment_node_ids: [referenced_fragment.id])

      expect(result).to have_attributes(fragment_count: 1, fact_count: 1, goods_nomenclature_count: 1)
      expect(TariffKnowledge::CompressedNoteGenerator)
        .to have_received(:call)
        .with(goods_nomenclature_sids: [123])
    end

    it 'regenerates compressed notes for goods affected through referenced ranges' do
      declarable_node = create(
        :tariff_knowledge_node,
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
      )
      create(
        :tariff_knowledge_edge,
        source_node: range_node,
        target_node: declarable_node,
        relationship_type: TariffKnowledge::Edge::EXPANDS_TO,
      )
      allow(TariffKnowledge::SemanticRuleFactExtractor)
        .to receive(:call)
        .and_return([{ 'source_span' => 'Heading 0101 covers live horses.' }])
      allow(TariffKnowledge::CompressedNoteGenerator).to receive(:call)

      result = described_class.call(fragment_node_ids: [referenced_fragment.id])

      expect(result).to have_attributes(fragment_count: 1, fact_count: 1, goods_nomenclature_count: 1)
      expect(TariffKnowledge::CompressedNoteGenerator)
        .to have_received(:call)
        .with(goods_nomenclature_sids: [123])
    end
  end
end
