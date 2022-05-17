RSpec.shared_examples_for 'a serialized goods nomenclature' do |type|
  subject(:serializer) { described_class.new(serializable, {}) }

  let(:serializable) { build(:goods_nomenclature, :with_description) }

  describe '#serializable_hash' do
    let(:expected_pattern) do
      {
        data: {
          id: serializable.goods_nomenclature_sid.to_s,
          type:,
          attributes: {
            goods_nomenclature_item_id: match(/\d{10}/),
            producline_suffix: match(/\d{2}/),
            description: '',
            formatted_description: nil,
          },
        },
      }
    end

    it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }
  end
end
