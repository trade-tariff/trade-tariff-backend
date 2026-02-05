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

    # -- POS-aware multi-word queries ----------------------------------------

    shared_context 'with POS bool clause' do
      subject(:pos_clause) do
        must_clauses = query.dig(:body, :query, :bool, :must)
        must_clauses.find { |c| c.dig(:bool, :should)&.any? { |m| m.key?(:multi_match) } }
      end

      let(:should_matches) { pos_clause.dig(:bool, :should) }

      def match_for(word)
        should_matches.find { |m| m.dig(:multi_match, :query) == word }
      end

      def boost_for(word)
        match_for(word)&.dig(:multi_match, :boost)
      end

      def all_queries
        should_matches.map { |m| m.dig(:multi_match, :query) }
      end
    end

    context 'with adjective + noun query (live horses)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'live horses' }

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('horses')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts the adjective with QUALIFIER_BOOST' do
        expect(boost_for('live')).to eq(described_class::QUALIFIER_BOOST)
      end

      it 'includes both terms' do
        expect(all_queries).to contain_exactly('live', 'horses')
      end

      it 'has no must clauses in the inner bool' do
        expect(pos_clause.dig(:bool, :must)).to be_nil
      end
    end

    context 'with noun + noun query (steel pipe)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'steel pipe' }

      it 'boosts both nouns with NOUN_BOOST' do
        expect(boost_for('steel')).to eq(described_class::NOUN_BOOST)
        expect(boost_for('pipe')).to eq(described_class::NOUN_BOOST)
      end

      it 'includes both terms' do
        expect(all_queries).to contain_exactly('steel', 'pipe')
      end
    end

    context 'with past participle modifier (dried fruit)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'dried fruit' }

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('fruit')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts the past participle (VBN) with QUALIFIER_BOOST' do
        expect(boost_for('dried')).to eq(described_class::QUALIFIER_BOOST)
      end
    end

    context 'with gerund modifier (running shoes)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'running shoes' }

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('shoes')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts the gerund (VBG) with QUALIFIER_BOOST' do
        expect(boost_for('running')).to eq(described_class::QUALIFIER_BOOST)
      end
    end

    context 'with gerund modifier (cutting tools)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'cutting tools' }

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('tools')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts the gerund (VBG) with QUALIFIER_BOOST' do
        expect(boost_for('cutting')).to eq(described_class::QUALIFIER_BOOST)
      end
    end

    context 'with adjective + noun + noun query (organic cotton fabric)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'organic cotton fabric' }

      it 'boosts nouns with NOUN_BOOST' do
        expect(boost_for('cotton')).to eq(described_class::NOUN_BOOST)
        expect(boost_for('fabric')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts the adjective with QUALIFIER_BOOST' do
        expect(boost_for('organic')).to eq(described_class::QUALIFIER_BOOST)
      end
    end

    context 'with conjunction noise word (fresh or chilled beef)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'fresh or chilled beef' }

      it 'excludes the conjunction "or"' do
        expect(all_queries).not_to include('or')
      end

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('beef')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts qualifiers with QUALIFIER_BOOST' do
        expect(boost_for('fresh')).to eq(described_class::QUALIFIER_BOOST)
        expect(boost_for('chilled')).to eq(described_class::QUALIFIER_BOOST)
      end

      it 'includes only significant terms' do
        expect(all_queries).to contain_exactly('fresh', 'chilled', 'beef')
      end
    end

    context 'with adjective + adjective + noun query (stainless steel bolts)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'stainless steel bolts' }

      it 'boosts nouns with NOUN_BOOST' do
        expect(boost_for('steel')).to eq(described_class::NOUN_BOOST)
        expect(boost_for('bolts')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts the adjective with QUALIFIER_BOOST' do
        expect(boost_for('stainless')).to eq(described_class::QUALIFIER_BOOST)
      end
    end

    context 'with adjective + noun + noun query (frozen chicken breast)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'frozen chicken breast' }

      it 'boosts nouns with NOUN_BOOST' do
        expect(boost_for('chicken')).to eq(described_class::NOUN_BOOST)
        expect(boost_for('breast')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts the adjective with QUALIFIER_BOOST' do
        expect(boost_for('frozen')).to eq(described_class::QUALIFIER_BOOST)
      end
    end

    context 'with expanded_query provided (live horses + synonyms)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'live horses' }
      let(:query_options) { { expanded_query: 'horses OR horse OR equine OR ponies' } }

      it 'boosts the noun from the original query' do
        expect(boost_for('horses')).to eq(described_class::NOUN_BOOST)
      end

      it 'boosts the adjective from the original query' do
        expect(boost_for('live')).to eq(described_class::QUALIFIER_BOOST)
      end

      it 'includes the sanitized expanded query without boost' do
        expanded_match = match_for('horses horse equine ponies')
        expect(expanded_match).to be_present
        expect(expanded_match.dig(:multi_match, :boost)).to be_nil
      end

      it 'strips OR/AND operators from the expanded query' do
        expanded_match = should_matches.find { |m| m.dig(:multi_match, :query).include?('equine') }

        expect(expanded_match.dig(:multi_match, :query)).not_to include('OR')
        expect(expanded_match.dig(:multi_match, :query)).not_to include('AND')
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

    # -- Structural filters --------------------------------------------------

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

    # -- SearchLabels --------------------------------------------------------

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
