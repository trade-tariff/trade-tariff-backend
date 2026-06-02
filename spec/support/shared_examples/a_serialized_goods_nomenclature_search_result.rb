RSpec.shared_examples_for 'a serialized goods nomenclature search result' do |type|
  subject(:serializer) { described_class.new(serializable) }

  let(:serializable_goods_nomenclature_class) do
    Data.define(
      :id,
      :goods_nomenclature_item_id,
      :goods_nomenclature_sid,
      :producline_suffix,
      :goods_nomenclature_class,
      :description,
      :formatted_description,
      :self_text,
      :classification_description,
      :full_description,
      :heading_description,
      :confidence,
      :declarable,
      :score,
    )
  end

  let(:serializable) do
    serializable_goods_nomenclature_class.new(
      id: 12_345,
      goods_nomenclature_item_id: '0100000000',
      goods_nomenclature_sid: 12_345,
      producline_suffix: '80',
      goods_nomenclature_class: type.to_s.classify,
      description: 'live animals',
      formatted_description: 'Live animals',
      self_text: nil,
      classification_description: nil,
      full_description: nil,
      heading_description: nil,
      confidence: nil,
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
