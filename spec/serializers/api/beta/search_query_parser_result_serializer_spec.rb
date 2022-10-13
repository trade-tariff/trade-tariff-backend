RSpec.describe Api::Beta::SearchQueryParserResultSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:search_query_parser_result) }

    let(:expected) do
      {
        data: {
          id: '240ad90c8bd0e29cc402ff257d033747',
          type: :search_query_parser_result,
          attributes: {
            corrected_search_query: 'halibut sausage stenolepis cheese binocular parsnip pharmacy paper',
            original_search_query: 'halbiut sausadge stenolepsis chese bnoculars parnsip farmacy pape',
            verbs: [],
            adjectives: [],
            nouns: %w[halibut sausage stenolepis cheese binocular parsnip pharmacy paper],
            noun_chunks: ['halibut sausage stenolepis cheese binocular parsnip pharmacy paper'],
            synonym_result: false,
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
