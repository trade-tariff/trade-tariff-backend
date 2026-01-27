RSpec.describe Search::SearchSuggestionsSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(suggestion).serializable_hash }

    let(:suggestion) do
      create(:search_suggestion, :search_reference,
             value: 'tea',
             goods_nomenclature_sid: 12_345,
             goods_nomenclature_class: 'Heading')
    end

    it 'returns the expected fields' do
      expect(serialized).to eq(
        value: 'tea',
        suggestion_type: 'search_reference',
        priority: 1,
        goods_nomenclature_sid: 12_345,
        goods_nomenclature_class: 'Heading',
      )
    end
  end
end
