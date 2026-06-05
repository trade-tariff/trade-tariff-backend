RSpec.describe TariffKnowledge::DeclarableContextCompressor do
  describe '.call' do
    subject(:compress) { described_class.call(goods_nomenclature_sids: [declarable.goods_nomenclature_sid]) }

    let(:declarable) { create(:commodity, goods_nomenclature_item_id: '0101210000') }
    let(:declarable_node) do
      TariffKnowledge::Node.create(
        node_type: TariffKnowledge::Node::GOODS_NOMENCLATURE,
        key: "goods_nomenclature:#{declarable.goods_nomenclature_sid}",
        goods_nomenclature_sid: declarable.goods_nomenclature_sid,
        goods_nomenclature_item_id: declarable.goods_nomenclature_item_id,
        producline_suffix: declarable.producline_suffix,
        goods_nomenclature_type: declarable.goods_nomenclature_class,
        title: declarable.goods_nomenclature_item_id,
      )
    end
    let(:rule_node) do
      TariffKnowledge::Node.create(
        node_type: TariffKnowledge::Node::RULE,
        key: 'rule:chapter-01:1',
        title: 'Chapter 01 note 1',
        content: 'This chapter covers all live animals except fish of heading 0301.',
        metadata: Sequel.pg_jsonb_wrap('rule_type' => 'excludes'),
        needs_review: true,
        generated_at: Time.zone.now,
      )
    end

    before do
      TariffKnowledge::Edge.create(
        source_node_id: rule_node.id,
        target_node_id: declarable_node.id,
        relationship_type: TariffKnowledge::Edge::APPLIES_TO,
        metadata: Sequel.pg_jsonb_wrap('resolution_reason' => 'source_scope'),
      )
    end

    it 'creates declarable context' do
      expect { compress }
        .to change(TariffKnowledge::DeclarableContext, :count).by(1)
    end

    it 'includes connected rules' do
      compress

      context = TariffKnowledge::DeclarableContext[declarable.goods_nomenclature_sid]
      expect(context.content).to include('Chapter 01 note 1')
      expect(context.content).to include('except fish')
    end
  end
end
