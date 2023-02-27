RSpec.describe Api::V2::SearchSuggestionSerializer do
  subject(:serialized) { described_class.new(search_suggestion).serializable_hash }

  let(:search_suggestion) do
    create(:search_suggestion, value: 'aluminium wire')

    SearchSuggestion.fuzzy_search('aluminum').first
  end

  it 'returns search suggestions' do
    expect(serialized).to eq(
      {
        data: {
          id: 'test',
          type: :search_suggestion,
          attributes: {
            value: 'aluminium wire',
            score: 0.411765,
            query: 'aluminum',
          },
        },
      },
    )
  end
end
