RSpec.describe Api::V2::Subheadings::HeadingSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { create(:heading, :with_description) }

  let(:expected_pattern) do
    {
      data: {
        id: serializable.goods_nomenclature_sid.to_s,
        type: 'heading',
        attributes: {
          goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
          description: serializable.description,
          formatted_description: serializable.formatted_description,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
