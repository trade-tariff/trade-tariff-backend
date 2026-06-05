RSpec.describe TariffKnowledge::Pipeline do
  describe '.call' do
    subject(:result) { described_class.call }

    let(:actual_update) do
      create(
        :customs_tariff_update,
        :approved,
        version: '1.30',
        validity_start_date: Time.zone.yesterday,
        validity_end_date: nil,
      )
    end
    let(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }
    let(:heading) { create(:heading, parent: chapter, goods_nomenclature_item_id: '0101000000') }

    before do
      section = create(:section, id: 1, title: 'Live animals; animal products', position: 1)
      chapter.add_section(section)
      chapter.save

      create(:commodity, parent: heading, goods_nomenclature_item_id: '0101210000')
      create(:commodity, parent: heading, goods_nomenclature_item_id: '0101290000')
      GoodsNomenclatures::TreeNode.refresh!

      create(
        :customs_tariff_chapter_note,
        :approved,
        customs_tariff_update: actual_update,
        chapter_id: '01',
        content: '1. This chapter covers live animals except fish of heading [0101](/headings/0101).',
      )
      create(
        :customs_tariff_section_note,
        :approved,
        customs_tariff_update: actual_update,
        section_id: 1,
        content: '1. Any reference in this section to an animal includes a reference to the young of that animal.',
      )

      TariffKnowledge::Node.create(
        node_type: TariffKnowledge::Node::NOTE_SOURCE,
        key: 'note_source:legacy_chapter_note:01',
        source_type: 'ChapterNote',
        source_id: '01',
        source_version: 'legacy',
      )
    end

    it 'builds reviewable graph coverage for every approved actual customs chapter and section note' do
      expect(result.coverage).to be_ok
      expect(result.source_count).to eq(2)
      expect(result.rule_count).to eq(2)
      expect(result.context_count).to eq(2)
      expect(result.coverage.findings).to be_empty

      expect(TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).select_map(:source_type))
        .to contain_exactly('CustomsTariffChapterNote', 'CustomsTariffSectionNote')
      expect(TariffKnowledge::Node.rules.where(needs_review: true).count).to eq(2)
      expect(TariffKnowledge::DeclarableContext.where(needs_review: true).count).to eq(2)
    end
  end
end
