RSpec.shared_examples_for 'a serialized goods nomenclature search result' do |type|
  subject(:serializer) { described_class.new(serializable) }

  let(:serializable) do
    OpenStruct.new(
      id: 12_345,
      goods_nomenclature_item_id: '0100000000',
      goods_nomenclature_sid: 12_345,
      producline_suffix: '80',
      goods_nomenclature_class: type.to_s.classify,
      description: 'live animals',
      formatted_description: 'Live animals',
      declarable: false,
      score: 12.5,
    )
  end

  describe '#serializable_hash' do
    let(:expected_pattern) do
      {
        data: {
          id: '12345',
          type:,
          attributes: {
            goods_nomenclature_item_id: '0100000000',
            producline_suffix: '80',
            goods_nomenclature_class: type.to_s.classify,
            description: 'live animals',
            formatted_description: 'Live animals',
            declarable: false,
            score: 12.5,
          },
        },
      }
    end

    it { expect(serializer.serializable_hash.as_json).to include_json(expected_pattern) }
  end
end
