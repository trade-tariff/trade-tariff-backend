RSpec.describe Search::GoodsNomenclatureQuery do
  subject(:query_instance) { described_class.new(query_string, date, **query_options) }

  let(:query_string) { 'horses' }
  let(:date) { Time.zone.today.iso8601 }
  let(:default_size) { AdminConfiguration.integer_value('opensearch_result_limit') }
  let(:default_noun_boost) { AdminConfiguration.integer_value('pos_noun_boost') }
  let(:default_qualifier_boost) { AdminConfiguration.integer_value('pos_qualifier_boost') }
  let(:query_options) { { size: default_size, noun_boost: default_noun_boost, qualifier_boost: default_qualifier_boost } }

  describe '#query' do
    subject(:query) { query_instance.query }

    it 'targets the goods nomenclatures index' do
      expect(query[:index]).to match(/goods_nomenclatures/)
    end

    it 'returns a hash with index and body' do
      expect(query).to include(:index, :body)
    end

    it 'limits results to DEFAULT_SIZE' do
      expect(query.dig(:body, :size)).to eq(default_size)
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
      let(:query_options) { { expanded_query: 'horses OR horse OR equine OR ponies', size: default_size, noun_boost: default_noun_boost, qualifier_boost: default_qualifier_boost } }

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
        expect(boost_for('horses')).to eq(default_noun_boost)
      end

      it 'boosts the adjective with QUALIFIER_BOOST' do
        expect(boost_for('live')).to eq(default_qualifier_boost)
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
        expect(boost_for('steel')).to eq(default_noun_boost)
        expect(boost_for('pipe')).to eq(default_noun_boost)
      end

      it 'includes both terms' do
        expect(all_queries).to contain_exactly('steel', 'pipe')
      end
    end

    context 'with past participle modifier (dried fruit)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'dried fruit' }

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('fruit')).to eq(default_noun_boost)
      end

      it 'boosts the past participle (VBN) with QUALIFIER_BOOST' do
        expect(boost_for('dried')).to eq(default_qualifier_boost)
      end
    end

    context 'with gerund modifier (running shoes)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'running shoes' }

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('shoes')).to eq(default_noun_boost)
      end

      it 'boosts the gerund (VBG) with QUALIFIER_BOOST' do
        expect(boost_for('running')).to eq(default_qualifier_boost)
      end
    end

    context 'with gerund modifier (cutting tools)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'cutting tools' }

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('tools')).to eq(default_noun_boost)
      end

      it 'boosts the gerund (VBG) with QUALIFIER_BOOST' do
        expect(boost_for('cutting')).to eq(default_qualifier_boost)
      end
    end

    context 'with adjective + noun + noun query (organic cotton fabric)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'organic cotton fabric' }

      it 'boosts nouns with NOUN_BOOST' do
        expect(boost_for('cotton')).to eq(default_noun_boost)
        expect(boost_for('fabric')).to eq(default_noun_boost)
      end

      it 'boosts the adjective with QUALIFIER_BOOST' do
        expect(boost_for('organic')).to eq(default_qualifier_boost)
      end
    end

    context 'with conjunction noise word (fresh or chilled beef)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'fresh or chilled beef' }

      it 'excludes the conjunction "or"' do
        expect(all_queries).not_to include('or')
      end

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('beef')).to eq(default_noun_boost)
      end

      it 'boosts qualifiers with QUALIFIER_BOOST' do
        expect(boost_for('fresh')).to eq(default_qualifier_boost)
        expect(boost_for('chilled')).to eq(default_qualifier_boost)
      end

      it 'includes only significant terms' do
        expect(all_queries).to contain_exactly('fresh', 'chilled', 'beef')
      end
    end

    context 'with determiner noise word (the engine parts)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'the engine parts' }

      it 'excludes the determiner "the"' do
        expect(all_queries).not_to include('the')
      end

      it 'boosts nouns with NOUN_BOOST' do
        expect(boost_for('engine')).to eq(default_noun_boost)
        expect(boost_for('parts')).to eq(default_noun_boost)
      end

      it 'includes only significant terms' do
        expect(all_queries).to contain_exactly('engine', 'parts')
      end
    end

    context 'with adjective + adjective + noun query (stainless steel bolts)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'stainless steel bolts' }

      it 'boosts nouns with NOUN_BOOST' do
        expect(boost_for('steel')).to eq(default_noun_boost)
        expect(boost_for('bolts')).to eq(default_noun_boost)
      end

      it 'boosts the adjective with QUALIFIER_BOOST' do
        expect(boost_for('stainless')).to eq(default_qualifier_boost)
      end
    end

    context 'with adjective + noun + noun query (frozen chicken breast)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'frozen chicken breast' }

      it 'boosts nouns with NOUN_BOOST' do
        expect(boost_for('chicken')).to eq(default_noun_boost)
        expect(boost_for('breast')).to eq(default_noun_boost)
      end

      it 'boosts the adjective with QUALIFIER_BOOST' do
        expect(boost_for('frozen')).to eq(default_qualifier_boost)
      end
    end

    context 'with preposition noise word (parts of engines)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'parts of engines' }

      it 'excludes the preposition "of"' do
        expect(all_queries).not_to include('of')
      end

      it 'boosts both nouns with NOUN_BOOST' do
        expect(boost_for('parts')).to eq(default_noun_boost)
        expect(boost_for('engines')).to eq(default_noun_boost)
      end

      it 'includes only significant terms' do
        expect(all_queries).to contain_exactly('parts', 'engines')
      end
    end

    context 'with preposition noise word (oil for engines)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'oil for engines' }

      it 'excludes the preposition "for"' do
        expect(all_queries).not_to include('for')
      end

      it 'boosts both nouns with NOUN_BOOST' do
        expect(boost_for('oil')).to eq(default_noun_boost)
        expect(boost_for('engines')).to eq(default_noun_boost)
      end
    end

    context 'with conjunction and multiple nouns (iron and steel bars)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'iron and steel bars' }

      it 'excludes the conjunction "and"' do
        expect(all_queries).not_to include('and')
      end

      it 'boosts all nouns with NOUN_BOOST' do
        expect(boost_for('iron')).to eq(default_noun_boost)
        expect(boost_for('steel')).to eq(default_noun_boost)
        expect(boost_for('bars')).to eq(default_noun_boost)
      end

      it 'includes only significant terms' do
        expect(all_queries).to contain_exactly('iron', 'steel', 'bars')
      end
    end

    context 'with hyphenated adjective (stainless-steel bolts)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'stainless-steel bolts' }

      it 'treats the hyphenated compound as a single qualifier' do
        expect(boost_for('stainless-steel')).to eq(default_qualifier_boost)
      end

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('bolts')).to eq(default_noun_boost)
      end
    end

    context 'with hyphenated adjective (non-alcoholic beer)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'non-alcoholic beer' }

      it 'treats the hyphenated compound as a single qualifier' do
        expect(boost_for('non-alcoholic')).to eq(default_qualifier_boost)
      end

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('beer')).to eq(default_noun_boost)
      end
    end

    context 'with acronym + noun (HDPE containers)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'HDPE containers' }

      it 'boosts the acronym as a noun with NOUN_BOOST' do
        expect(boost_for('HDPE')).to eq(default_noun_boost)
      end

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('containers')).to eq(default_noun_boost)
      end
    end

    context 'with number joined to unit (10mm bolts)' do
      include_context 'with POS bool clause'
      let(:query_string) { '10mm bolts' }

      it 'treats the joined number-unit as a noun' do
        expect(boost_for('10mm')).to eq(default_noun_boost)
      end

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('bolts')).to eq(default_noun_boost)
      end
    end

    context 'with number separated from unit (10 mm bolts)' do
      include_context 'with POS bool clause'
      let(:query_string) { '10 mm bolts' }

      it 'assigns no boost to the cardinal number' do
        expect(boost_for('10')).to be_nil
      end

      it 'still includes the number in the query' do
        expect(all_queries).to include('10')
      end

      it 'boosts the unit as a noun' do
        expect(boost_for('mm')).to eq(default_noun_boost)
      end

      it 'boosts the noun with NOUN_BOOST' do
        expect(boost_for('bolts')).to eq(default_noun_boost)
      end
    end

    context 'with verb mistagged as non-noun (car seat covers)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'car seat covers' }

      it 'boosts recognised nouns with NOUN_BOOST' do
        expect(boost_for('car')).to eq(default_noun_boost)
        expect(boost_for('seat')).to eq(default_noun_boost)
      end

      it 'assigns no boost to the mistagged verb' do
        expect(boost_for('covers')).to be_nil
      end

      it 'still includes the mistagged word in the query' do
        expect(all_queries).to include('covers')
      end
    end

    context 'with expanded_query provided (live horses + synonyms)' do
      include_context 'with POS bool clause'
      let(:query_string) { 'live horses' }
      let(:query_options) { { expanded_query: 'horses OR horse OR equine OR ponies', size: default_size, noun_boost: default_noun_boost, qualifier_boost: default_qualifier_boost } }

      it 'boosts the noun from the original query' do
        expect(boost_for('horses')).to eq(default_noun_boost)
      end

      it 'boosts the adjective from the original query' do
        expect(boost_for('live')).to eq(default_qualifier_boost)
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
      let(:query_options) { { pos_search: false, expanded_query: 'horses OR horse OR equine', size: default_size, noun_boost: default_noun_boost, qualifier_boost: default_qualifier_boost } }

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
      let(:query_options) { { size: 50, noun_boost: default_noun_boost, qualifier_boost: default_qualifier_boost } }

      it 'uses the custom size' do
        expect(query.dig(:body, :size)).to eq(50)
      end
    end

    context 'with custom boost values' do
      include_context 'with POS bool clause'
      let(:query_string) { 'live horses' }
      let(:query_options) { { size: default_size, noun_boost: 20, qualifier_boost: 5 } }

      it 'uses the custom noun boost' do
        expect(boost_for('horses')).to eq(20)
      end

      it 'uses the custom qualifier boost' do
        expect(boost_for('live')).to eq(5)
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
