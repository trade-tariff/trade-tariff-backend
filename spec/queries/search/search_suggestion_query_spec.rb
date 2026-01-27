RSpec.describe Search::SearchSuggestionQuery do
  subject(:query_instance) { described_class.new(query_string, date, index) }

  let(:query_string) { 'test query' }
  let(:date) { Time.zone.today }
  let(:index) { Search::SearchSuggestionsIndex.new }

  describe '#query' do
    subject(:query) { query_instance.query }

    it 'returns a hash with index and body' do
      expect(query).to include(:index, :body)
      expect(query[:index]).to eq(index.name)
    end

    it 'includes wildcard clauses for standard fields' do
      wildcards = query.dig(:body, :query, :bool, :should)
      wildcard_fields = wildcards.flat_map { |w| w[:wildcard].keys }

      expect(wildcard_fields).to include(
        'goods_nomenclature_item_id.keyword',
        'search_references.title.keyword',
        'chemicals.cus.keyword',
        'chemicals.cas_rn.keyword',
        'chemicals.name.keyword',
      )
    end

    it 'includes multi_match with standard fields' do
      must_clauses = query.dig(:body, :query, :bool, :must)
      multi_match = must_clauses.find { |c| c.key?(:multi_match) }

      expect(multi_match[:multi_match][:fields]).to include(
        'goods_nomenclature_item_id^5',
        'chemicals.cus^0.5',
        'chemicals.cas_rn^0.5',
        'search_references.title',
        'chemicals.name^0.1',
      )
    end

    context 'when SearchLabels is disabled (default)' do
      it 'does not include label fields in wildcards' do
        wildcards = query.dig(:body, :query, :bool, :should)
        wildcard_fields = wildcards.flat_map { |w| w[:wildcard].keys }

        expect(wildcard_fields).not_to include(
          'labels.known_brands.keyword',
          'labels.colloquial_terms.keyword',
          'labels.synonyms.keyword',
        )
      end

      it 'does not include label fields in multi_match' do
        must_clauses = query.dig(:body, :query, :bool, :must)
        multi_match = must_clauses.find { |c| c.key?(:multi_match) }

        expect(multi_match[:multi_match][:fields]).not_to include(
          'labels.description^0.5',
          'labels.known_brands^2',
          'labels.colloquial_terms^2',
          'labels.synonyms^1.5',
        )
      end
    end

    context 'when SearchLabels is enabled' do
      around do |example|
        SearchLabels.with_labels { example.run }
      end

      it 'includes label fields in wildcards' do
        wildcards = query.dig(:body, :query, :bool, :should)
        wildcard_fields = wildcards.flat_map { |w| w[:wildcard].keys }

        expect(wildcard_fields).to include(
          'labels.known_brands.keyword',
          'labels.colloquial_terms.keyword',
          'labels.synonyms.keyword',
        )
      end

      it 'includes label fields in multi_match' do
        must_clauses = query.dig(:body, :query, :bool, :must)
        multi_match = must_clauses.find { |c| c.key?(:multi_match) }

        expect(multi_match[:multi_match][:fields]).to include(
          'labels.description^0.5',
          'labels.known_brands^2',
          'labels.colloquial_terms^2',
          'labels.synonyms^1.5',
        )
      end
    end

    it 'filters out hidden goods nomenclatures' do
      must_clauses = query.dig(:body, :query, :bool, :must)
      hidden_filter = must_clauses.find { |c| c.dig(:bool, :must_not) }

      expect(hidden_filter).to be_present
      expect(hidden_filter.dig(:bool, :must_not, :terms, :goods_nomenclature_item_id)).to eq(HiddenGoodsNomenclature.codes)
    end

    it 'includes validity date filter' do
      must_clauses = query.dig(:body, :query, :bool, :must)
      validity_filter = must_clauses.find { |c| c.dig(:bool, :should)&.any? { |s| s.dig(:bool, :must)&.any? { |m| m.key?(:range) } } }

      expect(validity_filter).to be_present
    end
  end
end
