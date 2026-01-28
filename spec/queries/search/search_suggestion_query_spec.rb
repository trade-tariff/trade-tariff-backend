RSpec.describe Search::SearchSuggestionQuery do
  subject(:query_instance) { described_class.new(query_string, date) }

  let(:query_string) { 'test query' }
  let(:date) { Time.zone.today }

  describe '#query' do
    subject(:query) { query_instance.query }

    it 'returns a hash with index and body' do
      expect(query).to include(:index, :body)
      expect(query[:index]).to eq(Search::SearchSuggestionsIndex.new.name)
    end

    it 'includes an exact match term clause on value.keyword' do
      should_clauses = query.dig(:body, :query, :bool, :should)
      term = should_clauses.find { |c| c.key?(:term) }

      expect(term).to be_present
      expect(term.dig(:term, :'value.keyword', :value)).to eq('test query')
      expect(term.dig(:term, :'value.keyword', :boost)).to eq(100)
      expect(term.dig(:term, :'value.keyword', :case_insensitive)).to be true
    end

    it 'includes a wildcard clause on value.keyword' do
      should_clauses = query.dig(:body, :query, :bool, :should)
      wildcard = should_clauses.find { |c| c.key?(:wildcard) }

      expect(wildcard).to be_present
      expect(wildcard.dig(:wildcard, :'value.keyword', :value)).to eq('test query*')
      expect(wildcard.dig(:wildcard, :'value.keyword', :boost)).to eq(20)
    end

    it 'requires a match clause on value' do
      must_clauses = query.dig(:body, :query, :bool, :must)
      match = must_clauses.find { |c| c.key?(:match) }

      expect(match).to be_present
      expect(match.dig(:match, :value, :query)).to eq('test query')
      expect(match.dig(:match, :value, :fuzziness)).to eq('AUTO')
    end

    it 'sorts by score desc then priority asc' do
      sort = query.dig(:body, :sort)
      expect(sort).to eq([
        { _score: { order: 'desc' } },
        { priority: { order: 'asc' } },
      ])
    end

    it 'does not include validity date filter' do
      body = query[:body]
      expect(body.to_s).not_to include('validity_start_date')
      expect(body.to_s).not_to include('validity_end_date')
    end

    it 'does not include hidden goods nomenclature filter' do
      body = query[:body]
      expect(body.to_s).not_to include('must_not')
    end

    it 'does not include highlight' do
      expect(query[:body]).not_to have_key(:highlight)
    end
  end
end
