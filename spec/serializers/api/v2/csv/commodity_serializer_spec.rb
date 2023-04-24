RSpec.describe Api::V2::Csv::CommoditySerializer do
  describe '#serializable_array' do
    subject(:serializable) { described_class.new([commodity]).serializable_array }

    let(:parent) { create :commodity, :with_description, :with_heading }
    let(:commodity) { create :commodity, parent: }

    it 'includes header row' do
      expect(serializable[0]).to eq %i[
        description
        number_indents
        goods_nomenclature_item_id
        declarable
        leaf
        goods_nomenclature_sid
        formatted_description
        description_plain
        producline_suffix
        parent_sid
      ]
    end

    it 'serializes correctly' do
      expect(serializable[1]).to eq [
        commodity.description,
        commodity.number_indents,
        commodity.goods_nomenclature_item_id,
        true,
        true,
        commodity.goods_nomenclature_sid,
        commodity.description,
        commodity.description,
        commodity.producline_suffix,
        parent.goods_nomenclature_sid,
      ]
    end
  end
end
