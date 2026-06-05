RSpec.describe TariffKnowledge::CoverageAnalyzer do
  describe '.call' do
    subject(:coverage) { described_class.call(expected_sources:) }

    let(:expected_sources) { [source] }
    let(:source) do
      TariffKnowledge::RuleSource.new(
        key: 'customs_tariff_chapter_note:1.30:01',
        source_type: 'CustomsTariffChapterNote',
        source_id: '01',
        source_version: '1.30',
        title: 'Chapter 01 note',
        content: '1. This chapter covers live animals.',
        scope_type: 'chapter',
        scope_id: '01',
        validity_start_date: Time.zone.today,
        validity_end_date: nil,
      )
    end

    let(:source_node) do
      TariffKnowledge::Node.create(
        node_type: TariffKnowledge::Node::NOTE_SOURCE,
        key: "note_source:#{source.key}",
        title: source.title,
        content: source.content,
        source_type: source.source_type,
        source_id: source.source_id,
        source_version: source.source_version,
      )
    end
    let(:rule_node) do
      TariffKnowledge::Node.create(
        node_type: TariffKnowledge::Node::RULE,
        key: "rule:#{source.key}:1",
        title: 'Chapter 01 note 1',
        content: 'This chapter covers live animals.',
        metadata: Sequel.pg_jsonb_wrap('rule_type' => 'constrains'),
        needs_review: true,
      )
    end
    let(:declarable_node) do
      TariffKnowledge::Node.create(
        node_type: TariffKnowledge::Node::GOODS_NOMENCLATURE,
        key: 'goods_nomenclature:123',
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
        producline_suffix: '80',
        goods_nomenclature_type: 'Commodity',
      )
    end

    before do
      TariffKnowledge::Edge.create(
        source_node_id: source_node.id,
        target_node_id: rule_node.id,
        relationship_type: TariffKnowledge::Edge::HAS_FRAGMENT,
      )
      TariffKnowledge::Edge.create(
        source_node_id: rule_node.id,
        target_node_id: declarable_node.id,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
      )
      TariffKnowledge::DeclarableContext.create(
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
        content: 'Chapter 01 note 1: constrains. This chapter covers live animals.',
        context_hash: Digest::SHA256.hexdigest('content'),
        needs_review: true,
        generated_at: Time.zone.now,
      )
    end

    it 'passes when every source, rule, edge and context is present and reviewable' do
      expect(coverage).to be_ok
      expect(coverage.findings).to be_empty
    end

    context 'when no customs tariff sources are expected' do
      let(:expected_sources) { [] }

      it 'fails coverage' do
        expect(coverage).not_to be_ok
        expect(coverage.findings.map(&:code)).to include('no_expected_sources')
      end
    end

    context 'when a source is missing from the graph' do
      let(:expected_sources) do
        [
          source,
          source.with(key: 'customs_tariff_chapter_note:1.30:02', source_id: '02', scope_id: '02'),
        ]
      end

      it 'reports the missing source' do
        expect(coverage).not_to be_ok
        expect(coverage.findings.map(&:code)).to include('missing_source_nodes')
      end
    end

    context 'when a legacy source is present' do
      before do
        TariffKnowledge::Node.create(
          node_type: TariffKnowledge::Node::NOTE_SOURCE,
          key: 'note_source:legacy_chapter_note:01:1',
          source_type: 'ChapterNote',
          source_id: '1',
          source_version: 'legacy',
        )
      end

      it 'reports unexpected and non-customs source nodes' do
        expect(coverage).not_to be_ok
        expect(coverage.findings.map(&:code)).to include('unexpected_source_nodes', 'non_customs_source_nodes')
      end
    end
  end
end
