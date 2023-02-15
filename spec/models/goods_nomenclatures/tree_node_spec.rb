require 'rails_helper'

RSpec.describe GoodsNomenclatures::TreeNode do
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
end
