RSpec.describe Search::GoodsNomenclatureQuery do
  subject(:query_instance) { described_class.new(query_string, date, **query_options) }

  let(:query_string) { 'horses' }
  let(:date) { Time.zone.today.iso8601 }
  let(:query_options) { {} }

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

    context 'with single-word query' do
      let(:query_string) { 'horses' }

      describe 'multi_match clause' do
        subject(:multi_match) do
          must_clauses = query.dig(:body, :query, :bool, :must)
          must_clauses.find { |c| c.key?(:multi_match) }[:multi_match]
        end

        it 'searches with the query string' do
          expect(multi_match[:query]).to eq('horses')
        end

        it 'uses best_fields type' do
          expect(multi_match[:type]).to eq('best_fields')
        end

        it 'boosts description highest' do
          expect(multi_match[:fields]).to include('description^3')
        end

        it 'boosts search references above ancestor descriptions' do
          expect(multi_match[:fields]).to include('search_references^5')
          expect(multi_match[:fields]).to include('ancestor_descriptions')
        end
      end
    end

    context 'with multi-word adjective + noun query' do
      let(:query_string) { 'live horses' }

      describe 'POS-aware bool clause' do
        subject(:bool_clause) do
          must_clauses = query.dig(:body, :query, :bool, :must)
          must_clauses.find { |c| c.key?(:bool) && c.dig(:bool, :must)&.any? { |m| m.key?(:multi_match) } }
        end

        it 'puts nouns in must clauses' do
          must_matches = bool_clause.dig(:bool, :must)
          queries = must_matches.map { |m| m.dig(:multi_match, :query) }

          expect(queries).to eq(%w[horses])
        end

        it 'puts adjectives in should clauses' do
          should_matches = bool_clause.dig(:bool, :should)
          queries = should_matches.map { |m| m.dig(:multi_match, :query) }

          expect(queries).to eq(%w[live])
        end

        it 'uses best_fields type for all clauses' do
          all_matches = bool_clause.dig(:bool, :must) + bool_clause.dig(:bool, :should)
          types = all_matches.map { |m| m.dig(:multi_match, :type) }.uniq

          expect(types).to eq(%w[best_fields])
        end
      end
    end

    context 'with multi-word noun + noun query' do
      let(:query_string) { 'steel pipe' }

      describe 'POS-aware bool clause' do
        subject(:bool_clause) do
          must_clauses = query.dig(:body, :query, :bool, :must)
          must_clauses.find { |c| c.key?(:bool) && c.dig(:bool, :must)&.any? { |m| m.key?(:multi_match) } }
        end

        it 'puts all nouns in must clauses' do
          must_matches = bool_clause.dig(:bool, :must)
          queries = must_matches.map { |m| m.dig(:multi_match, :query) }

          expect(queries).to eq(%w[steel pipe])
        end

        it 'has no should clauses' do
          expect(bool_clause.dig(:bool, :should)).to be_nil
        end
      end
    end

    context 'with single-word query and expanded_query provided' do
      let(:query_string) { 'horses' }
      let(:query_options) { { expanded_query: 'horses OR horse OR equine OR ponies' } }

      describe 'multi_match clause' do
        subject(:multi_match) do
          must_clauses = query.dig(:body, :query, :bool, :must)
          must_clauses.find { |c| c.key?(:multi_match) }[:multi_match]
        end

        it 'uses the sanitized expanded query' do
          expect(multi_match[:query]).to eq('horses horse equine ponies')
        end
      end
    end

    context 'with expanded_query provided' do
      let(:query_string) { 'live horses' }
      let(:query_options) { { expanded_query: 'horses OR horse OR equine OR ponies' } }

      describe 'POS-aware bool clause with expanded query as should' do
        subject(:bool_clause) do
          must_clauses = query.dig(:body, :query, :bool, :must)
          must_clauses.find { |c| c.key?(:bool) && c.dig(:bool, :must)&.any? { |m| m.key?(:multi_match) } }
        end

        it 'puts nouns in must clauses from the original query' do
          must_matches = bool_clause.dig(:bool, :must)
          queries = must_matches.map { |m| m.dig(:multi_match, :query) }

          expect(queries).to eq(%w[horses])
        end

        it 'includes adjectives and sanitized expanded query in should clauses' do
          should_matches = bool_clause.dig(:bool, :should)
          queries = should_matches.map { |m| m.dig(:multi_match, :query) }

          expect(queries).to include('live')
          expect(queries).to include('horses horse equine ponies')
        end

        it 'strips OR/AND operators from the expanded query' do
          should_matches = bool_clause.dig(:bool, :should)
          expanded_match = should_matches.find { |m| m.dig(:multi_match, :query).include?('equine') }

          expect(expanded_match.dig(:multi_match, :query)).not_to include('OR')
          expect(expanded_match.dig(:multi_match, :query)).not_to include('AND')
        end
      end
    end

    context 'with pos_search disabled' do
      let(:query_string) { 'live horses' }
      let(:query_options) { { pos_search: false, expanded_query: 'horses OR horse OR equine' } }

      describe 'multi_match clause' do
        subject(:multi_match) do
          must_clauses = query.dig(:body, :query, :bool, :must)
          must_clauses.find { |c| c.key?(:multi_match) }[:multi_match]
        end

        it 'falls back to single multi_match with sanitized expanded query' do
          expect(multi_match[:query]).to eq('horses horse equine')
        end

        it 'uses best_fields type' do
          expect(multi_match[:type]).to eq('best_fields')
        end
      end
    end

    context 'with custom size' do
      let(:query_options) { { size: 50 } }

      it 'uses the custom size' do
        expect(query.dig(:body, :size)).to eq(50)
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
      let(:query_string) { 'horses' }

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
      let(:query_string) { 'horses' }

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
