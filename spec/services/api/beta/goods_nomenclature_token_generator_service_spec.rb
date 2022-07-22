RSpec.describe Api::Beta::GoodsNomenclatureTokenGeneratorService do
  describe '#call' do
    subject(:call) { described_class.new(goods_nomenclature).call }

    context 'when tokenising stop words' do
      let(:goods_nomenclature) { create(:commodity, :with_description, :stop_words_description) } # Live animals with some stop words

      it 'removes the stop words' do
        expected_tokens = %w[live animal]

        expect(call).to eq(expected_tokens)
      end
    end

    context 'when tokenising special non-word characters' do
      let(:goods_nomenclature) { create(:commodity, :with_description, :special_chars_description) } # Live#~#? (animals,) $* £' '

      it 'removes special characters' do
        expected_tokens = %w[live animal]

        expect(call).to eq(expected_tokens)
      end
    end

    context 'when tokenising negated words' do
      let(:goods_nomenclature) { create(:commodity, :with_description, :negated_description) } # Live animals, other than cheese

      it 'removes the negated words' do
        expected_tokens = %w[live animal]

        expect(call).to eq(expected_tokens)
      end
    end

    context 'when tokenising a word phrase' do
      let(:goods_nomenclature) { create(:commodity, :with_description, :word_phrase) } # 2 LiTres Or Less

      it 'returns the word phrase as a token' do
        expected_tokens = ['2 litres or less', '2', 'litre']

        expect(call).to eq(expected_tokens)
      end
    end
  end
end
