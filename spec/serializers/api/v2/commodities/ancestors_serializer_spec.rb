RSpec.describe Api::V2::Commodities::AncestorsSerializer do
  subject(:serializable) { described_class.new(commodity).serializable_hash.as_json }

  let(:commodity) { create(:commodity) }

  let(:expected) do
    {
      data: {
        id: commodity.goods_nomenclature_sid.to_s,
        type: :commodity,
        attributes: {
          producline_suffix: commodity.producline_suffix,
          description: commodity.description,
          number_indents: commodity.number_indents,
          goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
          formatted_description: commodity.formatted_description,
          description_plain: commodity.description_plain,
          validity_start_date: commodity.validity_start_date,
          validity_end_date: commodity.validity_end_date,
        },
      },
    }.as_json
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to include_json(expected)
    end
  end
end
