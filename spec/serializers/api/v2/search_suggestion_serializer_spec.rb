RSpec.describe Api::V2::SearchSuggestionSerializer do
  subject(:serialized) { described_class.new(search_suggestion).serializable_hash }

  let(:search_suggestion) do
    create(:search_suggestion, :search_reference, value: 'aluminium wire')

    SearchSuggestion.fuzzy_search('alu').first
  end

  it 'returns search suggestions' do
    expect(serialized).to include_json(
      {
        data: {
          id: 'test',
          type: eq(:search_suggestion),
          attributes: {
            value: 'aluminium wire',
            score: be_within(0.2).of(0.18),
            query: 'alu',
            suggestion_type: 'search_reference',
            priority: 1,
            goods_nomenclature_class: 'Heading',
          },
        },
      },
    )
  end
end
