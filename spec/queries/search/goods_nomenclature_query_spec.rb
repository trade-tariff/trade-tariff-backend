RSpec.describe Search::GoodsNomenclatureQuery do
  subject(:query_instance) { described_class.new(query_string, date) }

  let(:query_string) { 'live horses' }
  let(:date) { Time.zone.today.iso8601 }

  describe '#query' do
    subject(:query) { query_instance.query }

    it 'targets the goods nomenclatures index' do
      expect(query[:index]).to match(/goods_nomenclatures/)
    end

    it 'returns a hash with index and body' do
      expect(query).to include(:index, :body)
    end

    it 'limits results to DEFAULT_SIZE' do
      expect(query.dig(:body, :size)).to eq(described_class::DEFAULT_SIZE)
    end

    describe 'multi_match clause' do
      subject(:multi_match) do
        must_clauses = query.dig(:body, :query, :bool, :must)
        must_clauses.find { |c| c.key?(:multi_match) }[:multi_match]
      end

      it 'searches with the query string' do
        expect(multi_match[:query]).to eq('live horses')
      end

      it 'uses best_fields with and operator' do
        expect(multi_match[:type]).to eq('best_fields')
        expect(multi_match[:operator]).to eq('and')
      end

      it 'boosts description highest' do
        expect(multi_match[:fields]).to include('description^3')
      end

      it 'boosts search references above ancestor descriptions' do
        expect(multi_match[:fields]).to include('search_references^5')
        expect(multi_match[:fields]).to include('ancestor_descriptions')
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
      validity_filter = must_clauses.find do |c|
        c.dig(:bool, :should)&.any? { |s| s.dig(:bool, :must)&.any? { |m| m.key?(:range) } }
      end

      expect(validity_filter).to be_present
    end

    context 'when SearchLabels is disabled (default)' do
      it 'does not include label fields' do
        must_clauses = query.dig(:body, :query, :bool, :must)
        multi_match = must_clauses.find { |c| c.key?(:multi_match) }

        expect(multi_match[:multi_match][:fields]).not_to include(
          'labels.description',
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

      it 'includes label fields with boosting' do
        must_clauses = query.dig(:body, :query, :bool, :must)
        multi_match = must_clauses.find { |c| c.key?(:multi_match) }

        expect(multi_match[:multi_match][:fields]).to include(
          'labels.description',
          'labels.known_brands^2',
          'labels.colloquial_terms^2',
          'labels.synonyms^1.5',
        )
      end
    end
  end
end
