RSpec.describe Api::V2::Commodities::HeadingSerializer do
  subject(:serializable) { described_class.new(heading).serializable_hash.as_json }
  
  let(:heading) { create(:heading) }
  
  let(:expected) do
    {
      data: {
        id: heading.goods_nomenclature_sid.to_s,
        type: :heading,
        attributes: {
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          description: heading.description,
          formatted_description: heading.formatted_description,
          description_plain: heading.description_plain,
          validity_start_date: heading.validity_start_date,
          validity_end_date: heading.validity_end_date,
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
