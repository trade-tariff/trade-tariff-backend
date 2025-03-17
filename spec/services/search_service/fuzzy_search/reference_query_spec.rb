RSpec.describe SearchService::FuzzySearch::ReferenceQuery do
  describe '#query' do
    subject(:query) { described_class.new(query_string, date, index).query }

    let(:query_string) { 'foo' }
    let(:date) { Time.zone.today }
    let(:index) { SearchReference.elasticsearch_index }

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
end
