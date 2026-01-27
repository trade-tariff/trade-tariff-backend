RSpec.describe Api::Internal::SearchSuggestionSerializer do
  subject(:serialized) { described_class.new(suggestion).serializable_hash }

  let(:suggestion) do
    SearchSuggestion.unrestrict_primary_key
    SearchSuggestion.new.tap do |s|
      s.id = 12_345
      s.value = 'aluminium wire'
      s.type = 'search_reference'
      s.priority = 1
      s.goods_nomenclature_sid = 12_345
      s.goods_nomenclature_class = 'Heading'
      s[:score] = 15.3
      s[:query] = 'aluminium'
    end
  end

  it 'returns search suggestion attributes' do
    expect(serialized).to include_json(
      data: {
        id: be_present,
        type: eq(:search_suggestion),
        attributes: {
          value: 'aluminium wire',
          suggestion_type: 'search_reference',
          priority: 1,
          goods_nomenclature_class: 'Heading',
          score: 15.3,
          query: 'aluminium',
        },
      },
    )
  end

  context 'when query contains backslashes' do
    let(:suggestion) do
      SearchSuggestion.unrestrict_primary_key
      SearchSuggestion.new.tap do |s|
        s.id = 1
        s.value = 'test'
        s.type = 'search_reference'
        s.priority = 1
        s.goods_nomenclature_sid = 1
        s.goods_nomenclature_class = 'Heading'
        s[:score] = 1.0
        s[:query] = 'test\\value'
      end
    end

    it 'strips backslashes from the query' do
      attributes = serialized.dig(:data, :attributes)
      expect(attributes[:query]).to eq('testvalue')
    end
  end
end
