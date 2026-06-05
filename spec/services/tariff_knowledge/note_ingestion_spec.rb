RSpec.describe TariffKnowledge::NoteIngestion do
  describe '.call' do
    subject(:ingest) { described_class.call(sources: [source]) }

    let(:chapter) do
      create(
        :chapter,
        goods_nomenclature_item_id: '0100000000',
      )
    end
    let(:heading) do
      create(
        :heading,
        parent: chapter,
        goods_nomenclature_item_id: '0101000000',
      )
    end
    let(:source_declarable) do
      create(
        :commodity,
        parent: heading,
        goods_nomenclature_item_id: '0101210000',
      )
    end

    let(:referenced_chapter) do
      create(
        :chapter,
        goods_nomenclature_item_id: '0300000000',
      )
    end
    let(:referenced_heading) do
      create(
        :heading,
        parent: referenced_chapter,
        goods_nomenclature_item_id: '0301000000',
      )
    end
    let(:referenced_declarable) do
      create(
        :commodity,
        parent: referenced_heading,
        goods_nomenclature_item_id: '0301110000',
      )
    end

    let(:source) do
      TariffKnowledge::RuleSource.new(
        key: 'legacy_chapter_note:01',
        source_type: 'ChapterNote',
        source_id: '01',
        source_version: 'legacy',
        title: 'Chapter 01 note',
        content: '1. This chapter covers all live animals except fish of heading [0301](/headings/0301).',
        scope_type: 'chapter',
        scope_id: '01',
        validity_start_date: Time.zone.today,
        validity_end_date: nil,
      )
    end

    before do
      source_declarable
      referenced_declarable
      GoodsNomenclatures::TreeNode.refresh!
    end

    it 'creates source and rule nodes' do
      expect { ingest }
        .to change { TariffKnowledge::Node.where(node_type: TariffKnowledge::Node::NOTE_SOURCE).count }.by(1)
        .and change { TariffKnowledge::Node.rules.count }.by(1)
    end

    it 'creates declarable GN nodes' do
      ingest

      expect(TariffKnowledge::Node.goods_nomenclatures.map(:goods_nomenclature_item_id))
        .to include('0101210000', '0301110000')
    end

    it 'resolves source scope and references' do
      ingest

      rule = TariffKnowledge::Node.rules.first
      targets = TariffKnowledge::Edge
        .where(source_node_id: rule.id, relationship_type: TariffKnowledge::Edge::APPLIES_TO)
        .association_join(:target_node)
        .select_map(:target_node__goods_nomenclature_item_id)

      expect(targets).to include('0101210000', '0301110000')
    end

    context 'with customs tariff reference shapes' do
      let(:source) do
        TariffKnowledge::RuleSource.new(
          key: 'customs_tariff_chapter_note:1.31:01',
          source_type: 'CustomsTariffChapterNote',
          source_id: '01',
          source_version: '1.31',
          title: 'Chapter 01 note',
          content: '1. Goods of subheading 270111 and Section VI are subject to this chapter.',
          scope_type: 'chapter',
          scope_id: '01',
          validity_start_date: Time.zone.today,
          validity_end_date: nil,
        )
      end

      before do
        section_chapter = create(:chapter, goods_nomenclature_item_id: '2800000000')
        section_heading = create(:heading, parent: section_chapter, goods_nomenclature_item_id: '2801000000')
        create(:commodity, parent: section_heading, goods_nomenclature_item_id: '2801100000')

        subheading_chapter = create(:chapter, goods_nomenclature_item_id: '2700000000')
        subheading_heading = create(:heading, parent: subheading_chapter, goods_nomenclature_item_id: '2701000000')
        create(:commodity, parent: subheading_heading, goods_nomenclature_item_id: '2701110000')

        section = create(:section, id: 6, title: 'Products of the chemical or allied industries', position: 6)
        section_chapter.add_section(section)
        section_chapter.save
        GoodsNomenclatures::TreeNode.refresh!
      end

      it 'resolves subheading and section references to declarables' do
        ingest

        rule = TariffKnowledge::Node.rules.first
        targets = TariffKnowledge::Edge
          .where(source_node_id: rule.id, relationship_type: TariffKnowledge::Edge::APPLIES_TO)
          .association_join(:target_node)
          .select_map(:target_node__goods_nomenclature_item_id)

        expect(targets).to include('2701110000', '2801100000')
      end
    end

    it 'is idempotent' do
      ingest

      expect { described_class.call(sources: [source]) }
        .not_to change(TariffKnowledge::Node, :count)
    end
  end
end
