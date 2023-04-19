require 'rails_helper'

RSpec.describe GoodsNomenclatures::TreeNodeOverride do
  describe 'attributes' do
    it { is_expected.to respond_to :goods_nomenclature_indent_sid }
    it { is_expected.to respond_to :depth }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject { described_class.new.tap(&:valid?).errors }

    it { is_expected.to include goods_nomenclature_indent_sid: ['is not present'] }
    it { is_expected.to include depth: ['is not present'] }
  end

  describe 'timestamps' do
    subject(:override) do
      described_class.create \
        goods_nomenclature_indent_sid: bad_indent.goods_nomenclature_indent_sid,
        depth: bad_indent.number_indents + 3
    end

    let(:bad_indent) { create :goods_nomenclature_indent }

    it { is_expected.to have_attributes created_at: be_present }
    it { is_expected.to have_attributes updated_at: be_nil }

    context 'when modified' do
      before { override.save }

      it { is_expected.to have_attributes updated_at: be_present }
    end
  end
end
