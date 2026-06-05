RSpec.describe TariffKnowledge::StaleGraphPruner do
  describe '.call' do
    subject(:prune) { described_class.call(expected_sources: [expected_source]) }

    let(:expected_source) do
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

    let(:stale_source) do
      TariffKnowledge::Node.create(
        node_type: TariffKnowledge::Node::NOTE_SOURCE,
        key: 'note_source:legacy_chapter_note:01:1',
        source_type: 'ChapterNote',
      )
    end
    let(:stale_rule) do
      TariffKnowledge::Node.create(
        node_type: TariffKnowledge::Node::RULE,
        key: 'rule:legacy_chapter_note:01:1:1',
        needs_review: true,
      )
    end

    before do
      TariffKnowledge::Edge.create(
        source_node_id: stale_source.id,
        target_node_id: stale_rule.id,
        relationship_type: TariffKnowledge::Edge::HAS_FRAGMENT,
      )
      TariffKnowledge::DeclarableContext.create(
        goods_nomenclature_sid: 123,
        goods_nomenclature_item_id: '0101210000',
        content: 'stale context',
        context_hash: Digest::SHA256.hexdigest('stale context'),
        generated_at: Time.zone.now,
      )
    end

    it 'removes stale note source graph rows and generated contexts' do
      expect { prune }
        .to change(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE), :count).by(-1)
        .and change(TariffKnowledge::Node.rules, :count).by(-1)
        .and change(TariffKnowledge::DeclarableContext, :count).by(-1)
    end
  end
end
