RSpec.describe Search::BulkSearchSerializer do
  describe '#serializable_hash' do
    subject(:result) { described_class.new(record).serializable_hash }

    let(:record) do
      Hashie::TariffMash.new(
        number_of_digits: 8,
        short_code: '03028910',
        indexed_descriptions: ['FISH AND CRUSTACEANS, MOLLUSCS AND OTHER AQUATIC INVERTEBRATES', 'Fish, fresh or chilled', 'Other fish', 'Other'],
        search_references: ['fish', 'fish - fresh or chilled', 'fish - livers', 'fish - roes'],
        intercept_terms: ['red mullet'],
      )
    end

    it 'returns a serialized record' do
      expect(result).to eq(
        number_of_digits: 8,
        short_code: '03028910',
        indexed_descriptions: 'FISH AND CRUSTACEANS, MOLLUSCS AND OTHER AQUATIC INVERTEBRATES|Fish, fresh or chilled|Other fish|Other',
        search_references: 'fish|fish - fresh or chilled|fish - livers|fish - roes',
        intercept_terms: 'red mullet',
      )
    end
  end
end
