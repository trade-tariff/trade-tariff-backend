RSpec.describe Search::BulkSearchSerializer do
  describe '#serializable_hash' do
    subject(:result) { described_class.new(record).serializable_hash }

    let(:record) do
      Hashie::TariffMash.new(
        number_of_digits: 8,
        short_code: '05119190',
        indexed_descriptions: [
          'Other',
          'PRODUCTS OF ANIMAL ORIGIN, NOT ELSEWHERE SPECIFIED OR INCLUDED',
          'Animal products not elsewhere specified or included; dead animals of Chapter 1 or 3, unfit for human consumption',
          'Products of fish or crustaceans, molluscs or other aquatic invertebrates; dead animals of Chapter 3',
        ],
        indexed_tradeset_descriptions: [
          'bloodworm',
          'un3373 biological substance categor',
          'pacific ocean marine plankton',
          'dungorman eddie sexed',
          'fixed fish tissue',
          'un3373 biological substance/animal',
          'fish flesh',
          'tissue samplkes',
          'dog snacks',
          'biological sample animal products n',
          'drieddeadbutterflyspecimen',
          'biological samples for analysis nontoxi nonhaz',
        ],
        search_references: [
          'eggs, fish for hatching',
          'fish - bladders and waste, inedible dead, livers and roes, ova, fish for hatching',
        ],
        intercept_terms: [],
      )
    end

    it 'returns a serialized record' do
      expect(result).to eq(
        number_of_digits: 8,
        short_code: '05119190',
        indexed_descriptions: 'Other|PRODUCTS OF ANIMAL ORIGIN, NOT ELSEWHERE SPECIFIED OR INCLUDED|Animal products not elsewhere specified or included; dead animals of Chapter 1 or 3, unfit for human consumption|Products of fish or crustaceans, molluscs or other aquatic invertebrates; dead animals of Chapter 3',
        indexed_tradeset_descriptions: 'bloodworm|un3373 biological substance categor|pacific ocean marine plankton|dungorman eddie sexed|fixed fish tissue|un3373 biological substance/animal|fish flesh|tissue samplkes|dog snacks|biological sample animal products n|drieddeadbutterflyspecimen|biological samples for analysis nontoxi nonhaz',
        search_references: 'eggs, fish for hatching|fish - bladders and waste, inedible dead, livers and roes, ova, fish for hatching',
        intercept_terms: '',
      )
    end
  end
end
