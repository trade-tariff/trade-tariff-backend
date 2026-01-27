RSpec.describe Search::Fuzzy::ReferenceQuery do
  describe '#query' do
    subject(:query) { described_class.new(query_string, date, index).query }

    let(:query_string) { 'foo' }
    let(:date) { Time.zone.today }
    let(:index) { Search::SearchReferenceIndex.new }

    let(:pattern) do
      {
        index: 'tariff-test-search_references-uk',
        search: {
          query: {
            bool: {
              must: { multi_match: { query: 'foo', operator: 'and', fields: %w[title_indexed] } },
              filter: { bool: { must: [{ term: { reference_class: 'Search_reference' } }] } },
            },
          },
        },
      }
    end

    it { is_expected.to include_json pattern }
  end

  describe '#match_type' do
    it 'returns :reference_match' do
      instance = described_class.new('test', Time.zone.today, Search::SearchReferenceIndex.new)
      expect(instance.match_type).to eq(:reference_match)
    end
  end
end
