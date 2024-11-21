require 'rails_helper'

RSpec.describe GoodsNomenclatures::TreeNode do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  describe 'Sequel::Model config' do
    subject { described_class }

    it { is_expected.to have_attributes primary_key: :goods_nomenclature_indent_sid }
  end

  describe 'attributes' do
    it { is_expected.to respond_to :goods_nomenclature_sid }
    it { is_expected.to respond_to :position }
    it { is_expected.to respond_to :depth }
    it { is_expected.to respond_to :validity_start_date }
    it { is_expected.to respond_to :validity_end_date }
  end

  describe '.refresh!' do
    before do
      GoodsNomenclatureIndent.unrestrict_primary_key
      GoodsNomenclatureIndent.create indent_attrs
      GoodsNomenclatureIndent.restrict_primary_key
    end

    let(:commodity) { create :commodity }

    let :indent_attrs do
      attributes_for :goods_nomenclature_indent,
                     goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                     goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                     productline_suffix: commodity.producline_suffix
    end

    it 'updates the tree nodes view from the indents table' do
      expect { described_class.refresh! }.to change(described_class, :count)
    end
  end

  describe 'materialized view content' do
    subject do
      described_class
        .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
        .first
    end

    let(:commodity) { create :goods_nomenclature }

    let :expected_position do
      commodity.goods_nomenclature_item_id.to_i * 100 +
        commodity.producline_suffix.to_i
    end

    it { is_expected.to have_attributes position: expected_position }
    it { is_expected.to have_attributes number_indents: commodity.number_indents }
  end

  describe '.previous_sibling' do
    subject do
      described_class.previous_sibling(origin.tree_node.position, origin.tree_node.depth)
                     .first
                     .values[:previous_sibling]
    end

    let(:subheading) { create :commodity, :with_chapter_and_heading }
    let(:siblings) { create_list :commodity, 3, parent: subheading }

    context 'with first sibling' do
      let(:origin) { siblings.first }

      it { is_expected.to be_nil }
    end

    context 'with second sibling' do
      let(:origin) { siblings.second }

      it { is_expected.to eq siblings.first.tree_node.position }
    end

    context 'with third sibling' do
      let(:origin) { siblings.third }

      it { is_expected.to eq siblings.second.tree_node.position }
    end
  end

  describe '.next_sibling' do
    subject do
      described_class.next_sibling(origin.tree_node.position, origin.tree_node.depth)
                     .first
                     .values[:next_sibling]
    end

    let(:subheading) { create :commodity, :with_chapter_and_heading }
    let(:siblings) { create_list :commodity, 3, parent: subheading }

    context 'with first sibling' do
      let(:origin) { siblings.first }

      it { is_expected.to eq siblings.second.tree_node.position }
    end

    context 'with second sibling' do
      let(:origin) { siblings.second }

      it { is_expected.to eq siblings.third.tree_node.position }
    end

    context 'with third sibling' do
      let(:origin) { siblings.third }

      it { is_expected.to be_nil }
    end
  end

  describe '.next_sibling_or_end' do
    subject do
      described_class.db.select(
        described_class.next_sibling_or_end(origin.tree_node.position,
                                            origin.tree_node.depth),
      ).first[:coalesce]
    end

    let(:subheading) { create :commodity, :with_chapter_and_heading }
    let(:siblings) { create_list :commodity, 3, parent: subheading }

    context 'with first sibling' do
      let(:origin) { siblings.first }

      it { is_expected.to eq siblings.second.tree_node.position }
    end

    context 'with third sibling' do
      let(:origin) { siblings.third }

      it { is_expected.to eq described_class::END_OF_TREE }
    end
  end

  describe '.ancestor_node_constraints' do
    subject { described_class.ancestor_node_constraints(table1, table2) }

    let(:table1) { GoodsNomenclatures::TreeNodeAlias.new(:table1) }
    let(:table2) { GoodsNomenclatures::TreeNodeAlias.new(:table2) }

    it { is_expected.to be_instance_of Sequel::SQL::BooleanExpression }
  end

  describe '.descendant_node_constraints' do
    subject { described_class.descendant_node_constraints(table1, table2) }

    let(:table1) { GoodsNomenclatures::TreeNodeAlias.new(:table1) }
    let(:table2) { GoodsNomenclatures::TreeNodeAlias.new(:table2) }

    it { is_expected.to be_instance_of Sequel::SQL::BooleanExpression }
  end

  describe '.join_child_sids' do
    subject do
      described_class.join_child_sids
                     .all
                     .group_by(&:goods_nomenclature_sid)
                     .transform_values do |nodes|
                       nodes.map { |node| node.values[:child_sid] }
                     end
    end

    before { commodities }

    let(:subheading) { create :subheading, :with_chapter_and_heading }
    let(:commodities) { create_list :commodity, 2, parent: subheading }

    it { is_expected.to include subheading.chapter.pk => [subheading.parent.pk] }
    it { is_expected.to include subheading.pk => commodities.map(&:pk) }
    it { is_expected.to include commodities.first.pk => [nil] }
  end

  describe '#goods_nomenclature relationship' do
    subject(:commodity) { tree_node.goods_nomenclature }

    let(:indent) { commodity.goods_nomenclature_indent }

    let :tree_node do
      commodity = create :commodity,
                         :with_indent,
                         goods_nomenclature_item_id: '0101010101',
                         indents: 1

      described_class
        .actual
        .first(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
    end

    it { is_expected.to be_instance_of Commodity }
    it { is_expected.to have_attributes goods_nomenclature_sid: tree_node.goods_nomenclature_sid }

    it 'reciprocates correctly' do
      expect(commodity.tree_node.object_id).to eq tree_node.object_id
    end
  end
end
