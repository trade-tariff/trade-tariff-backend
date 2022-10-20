RSpec.describe Api::Beta::AncestorSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) do
      Hashie::TariffMash.new(
        id: 27_623,
        goods_nomenclature_item_id: '0100000000',
        producline_suffix: '80',
        goods_nomenclature_class: 'Chapter',
        description: 'LIVE ANIMALS',
        description_indexed: 'LIVE ANIMALS',
        formatted_description: 'Live Animals',
      )
    end

    let(:expected) do
      {
        data: {
          id: '27623',
          type: :ancestor,
          attributes: {
            goods_nomenclature_item_id: '0100000000',
            producline_suffix: '80',
            description: 'LIVE ANIMALS',
            description_indexed: 'LIVE ANIMALS',
            formatted_description: 'Live Animals',
            goods_nomenclature_class: 'Chapter',
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
