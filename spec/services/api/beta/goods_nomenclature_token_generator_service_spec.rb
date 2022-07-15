RSpec.describe Api::Beta::GoodsNomenclatureTokenGeneratorService do
  describe '#call' do
    subject(:call) { described_class.new(goods_nomenclatures).call }

    context 'when tokenising a full ancestors tree' do
      let(:goods_nomenclatures) do
        commodity = create(:commodity, :with_ancestors)

        goods_nomenclature = GoodsNomenclature.find(goods_nomenclature_sid: commodity.goods_nomenclature_sid)

        goods_nomenclature.ancestors << goods_nomenclature
      end

      it 'returns the correct reversed and analysed tokens' do
        expected_tokens = [
          { analysed_token: 'horse', original_token: 'Horses' },
          { analysed_token: 'animal', original_token: 'animals' },
          { analysed_token: 'live', original_token: 'Live' },
          { analysed_token: 'hinny', original_token: 'hinnies' },
          { analysed_token: 'mule', original_token: 'mules' },
          { analysed_token: 'ass', original_token: 'asses,' },
          { analysed_token: 'horse', original_token: 'horses,' },
          { analysed_token: 'live', original_token: 'Live' },
        ]

        expect(call).to eq(expected_tokens)
      end
    end

    context 'when tokenising stop words' do
      let(:goods_nomenclatures) { [create(:commodity, :with_description, :stop_words_description)] } # Live animals with some stop words

      it 'removes the stop words' do
        expected_tokens = [
          { analysed_token: 'animal', original_token: 'animals' },
          { analysed_token: 'live', original_token: 'Live' },
        ]

        expect(call).to eq(expected_tokens)
      end
    end

    context 'when tokenising special non-word characters' do
      let(:goods_nomenclatures) { [create(:commodity, :with_description, :special_chars_description)] } # Live#~#? (animals,) $* £' '

      it 'removes special characters' do
        expected_tokens = [
          { analysed_token: 'animal', original_token: '(animals,)' },
          { analysed_token: 'live', original_token: 'Live#~#?' },
        ]

        expect(call).to eq(expected_tokens)
      end
    end

    context 'when tokenising negated words' do
      let(:goods_nomenclatures) { [create(:commodity, :with_description, :negated_description)] } # Live animals, other than cheese

      it 'removes the negated words' do
        expected_tokens = [
          { analysed_token: 'animal', original_token: 'animals' },
          { analysed_token: 'live', original_token: 'Live' },
        ]

        expect(call).to eq(expected_tokens)
      end
    end
  end
end
