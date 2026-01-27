RSpec.describe SearchService::FuzzySearch do
  let(:query_string) { 'apples' }
  let(:data_serializer) { Api::V2::SearchSerializationService.new }

  around do |example|
    TimeMachine.now { example.run }
  end

  describe '#search!' do
    subject(:fuzzy_search) { described_class.new(query_string).search! }

    context 'when searching across multiple indexes' do
      before do
        # Create multiple goods nomenclature items with matching descriptions
        chapter = create :chapter, :with_description,
                         goods_nomenclature_item_id: '0800000000',
                         description: 'Apples, pears and quinces'
        heading = create :heading, :with_description,
                         goods_nomenclature_item_id: '0808000000',
                         description: 'Apples, fresh'
        commodity = create :commodity, :with_description,
                           goods_nomenclature_item_id: '0808101000',
                           description: 'Cider apples, fresh'

        # Explicitly index test data
        index_model(chapter)
        index_model(heading)
        index_model(commodity)
      end

      it 'returns results from multiple indexes' do
        results = fuzzy_search.serializable_hash

        expect(results[:type]).to eq('fuzzy_match')
        expect(results[:goods_nomenclature_match]).to be_present

        match_data = results[:goods_nomenclature_match]

        expect(match_data['chapters']).not_to be_empty
        expect(match_data['headings']).not_to be_empty
        expect(match_data['commodities']).not_to be_empty
      end

      it 'returns correct chapter data' do
        results = fuzzy_search.serializable_hash
        chapters = results.dig(:goods_nomenclature_match, 'chapters')

        expect(chapters.size).to be >= 1
        chapter = chapters.find { |c| c.dig('_source', 'goods_nomenclature_item_id') == '0800000000' }
        expect(chapter).to be_present
        expect(chapter['_source']['description']).to include('Apples')
      end

      it 'returns correct heading data' do
        results = fuzzy_search.serializable_hash
        headings = results.dig(:goods_nomenclature_match, 'headings')

        expect(headings.size).to be >= 1
        heading = headings.find { |h| h.dig('_source', 'goods_nomenclature_item_id') == '0808000000' }
        expect(heading).to be_present
        expect(heading['_source']['description']).to include('Apples')
      end

      it 'returns correct commodity data' do
        results = fuzzy_search.serializable_hash
        commodities = results.dig(:goods_nomenclature_match, 'commodities')

        expect(commodities.size).to be >= 1
        commodity = commodities.find { |c| c.dig('_source', 'goods_nomenclature_item_id') == '0808101000' }
        expect(commodity).to be_present
        expect(commodity['_source']['description']).to include('apples')
      end
    end

    context 'when searching with reference matches' do
      let(:query_string) { 'tropical fruit' }

      before do
        chapter = create :chapter, :with_description,
                         goods_nomenclature_item_id: '0800000000',
                         description: 'Dates, figs, pineapples'

        heading = create :heading, :with_description,
                         goods_nomenclature_item_id: '0804000000',
                         description: 'Pineapples'

        create :search_suggestion,
               :search_reference,
               :with_search_reference,
               goods_nomenclature: chapter,
               value: 'tropical fruit'

        create :search_suggestion,
               :search_reference,
               :with_search_reference,
               goods_nomenclature: heading,
               value: 'tropical fruit imports'

        # Explicitly index test data
        index_model(chapter)
        index_model(heading)
        SearchReference.all.each { |sr| index_model(sr) }
      end

      it 'returns reference matches' do
        results = fuzzy_search.serializable_hash

        expect(results[:type]).to eq('fuzzy_match')
        expect(results[:reference_match]).to be_present

        # Verify we get reference matches
        reference_data = results[:reference_match]
        all_references = reference_data.values.flatten

        expect(all_references).not_to be_empty
      end
    end

    context 'when no results match' do
      let(:query_string) { 'xyznonexistent' }

      it 'returns empty results structure' do
        results = fuzzy_search.serializable_hash

        expect(results[:type]).to eq('fuzzy_match')
        expect(results[:goods_nomenclature_match]).to be_present
        expect(results[:reference_match]).to be_present

        # All index types should have empty arrays
        %w[chapters headings commodities].each do |index_type|
          expect(results.dig(:goods_nomenclature_match, index_type)).to eq([])
          expect(results.dig(:reference_match, index_type)).to eq([])
        end
      end
    end

    context 'when OpenSearch raises an error' do
      before do
        allow(TradeTariffBackend.search_client).to receive(:msearch)
          .and_raise(OpenSearch::Transport::Transport::Error)
      end

      it 'returns BLANK_RESULT without raising' do
        results = fuzzy_search.serializable_hash

        expect(results[:type]).to eq('fuzzy_match')
        expect(results).to include(SearchService::BaseSearch::BLANK_RESULT)
      end
    end
  end

  describe 'query generation' do
    subject(:fuzzy_search) { described_class.new(query_string) }

    it 'generates queries for all non-excluded indexes' do
      queries = fuzzy_search.send(:build_queries)

      # We should have 2 queries per index (GoodsNomenclatureQuery + ReferenceQuery)
      # For 6 indexes, that's 12 queries total
      non_excluded_indexes = TradeTariffBackend.search_indexes.reject(&:exclude_from_search_results?)
      expected_query_count = non_excluded_indexes.size * 2

      expect(queries.size).to eq(expected_query_count)
    end

    it 'generates both GoodsNomenclatureQuery and ReferenceQuery for each index' do
      queries = fuzzy_search.send(:build_queries)

      goods_nomenclature_queries = queries.select do |q|
        q.is_a?(Search::Fuzzy::GoodsNomenclatureQuery)
      end

      reference_queries = queries.select do |q|
        q.is_a?(Search::Fuzzy::ReferenceQuery)
      end

      non_excluded_indexes = TradeTariffBackend.search_indexes.reject(&:exclude_from_search_results?)

      expect(goods_nomenclature_queries.size).to eq(non_excluded_indexes.size)
      expect(reference_queries.size).to eq(non_excluded_indexes.size)
    end

    it 'memoizes the queries' do
      first_call = fuzzy_search.send(:build_queries)
      second_call = fuzzy_search.send(:build_queries)

      expect(first_call.object_id).to eq(second_call.object_id)
    end
  end
end
