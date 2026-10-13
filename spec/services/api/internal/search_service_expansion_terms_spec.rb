RSpec.describe Api::Internal::SearchService do
  let(:question_result) do
    InteractiveSearchService::Result.new(
      type: :questions,
      data: [{ question: 'Which kind?', options: ['Fillet', 'Frozen', 'Woven cotton'] }],
      attempt: 1,
      model: 'test',
      result_limit: nil,
      ranking_source: 'model_questions',
    )
  end

  before do
    allow(AdminConfiguration).to receive(:option_value).and_call_original
    allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('opensearch')
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(true)
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(false)
    allow(AdminConfiguration).to receive(:enabled?).with('refine_search_with_answers_enabled').and_return(true)
    allow(AdminConfiguration).to receive(:enabled?).with('search_compressed_notes_enabled').and_return(false)
    allow(Search::Instrumentation).to receive(:search) { |**_kwargs, &block| block.call.first }
    allow(Search::ExpansionVocabulary).to receive(:lookup) do |words|
      Search::ExpansionVocabulary::Lookup.new(status: :ready, words: words.to_set, generation: 'test')
    end
    TradeTariffRequest.request_source = TradeTariffRequest::FRONTEND_REQUEST_SOURCE
    allow(SearchExport::JourneyProjection).to receive(:record).and_call_original
    allow(Search::Instrumentation).to receive(:evaluation_journey_recorded)
    allow(InteractiveSearchService).to receive(:call).and_return(question_result)
    allow(TradeTariffBackend.search_client).to receive(:search).and_return(
      'hits' => { 'hits' => [{ '_score' => 10,
                               '_source' => {
                                 'goods_nomenclature_sid' => 1,
                                 'goods_nomenclature_item_id' => '4202210000',
                                 'producline_suffix' => '80',
                                 'goods_nomenclature_class' => 'Commodity',
                                 'description' => 'leather handbags',
                                 'formatted_description' => 'Leather handbags',
                                 'declarable' => true,
                               } }] },
    )
  end

  after do
    TradeTariffRequest.search_failures = nil
    TradeTariffRequest.request_source = nil
  end

  describe '#call' do
    [
      ['chicken', 'chicken', %w[Fillet Frozen], []],
      ['chicken', 'chicken chicken cuts, frozen', %w[Fillet Frozen], ['chicken cuts, frozen']],
      ['chicken', 'poultry meat', ['Fillet', 'Woven cotton'], ['poultry meat']],
      ['chicken', 'chicken Fillet Frozen', %w[Fillet Frozen], ['Fillet Frozen']],
      ['chicken Fillet', 'chicken Fillet', %w[Fillet fillet Frozen Frozen], []],
      ['cotton shirts', 'cotton shirts', ['Woven cotton', 'cotton'], []],
    ].each do |query, expanded, selections, expected_terms|
      it "preserves expansion #{expected_terms.inspect} through answers #{selections.inspect} for #{query.inspect}" do
        allow(ExpandSearchQueryService).to receive(:call) do |input, **|
          ExpandSearchQueryService::Result.new(expanded_query: input == query ? expanded : input, reason: nil)
        end
        params = { q: query, request_id: 'expansion-journey', answers: [] }
        response = described_class.new(params).call

        selections.each do |selection|
          meta = response.fetch(:meta).fetch(:interactive_search)
          expect(meta.fetch(:query_expansion)).to eq(ai_terms: expected_terms)
          params = params.merge(
            expanded_query: meta[:expanded_query],
            query_expansion: meta[:query_expansion],
            answers: params[:answers] + [{ question: 'Which kind?', options: selections, answer: selection }],
          )
          response = described_class.new(params).call
        end

        allow(InteractiveSearchService).to receive(:call).and_return(nil)
        described_class.new(params).call

        expect(SearchExport::JourneyProjection).to have_received(:record).with(
          hash_including(query: query, expansion_terms: expected_terms),
        ).at_least(:once)
        expect(Search::Instrumentation).to have_received(:evaluation_journey_recorded).with(
          hash_including(query: query, expansion_terms: expected_terms),
        ).once
        expected_query = selections.reduce(expanded) do |value, selection|
          value.downcase.include?(selection.downcase) ? value : "#{value} #{selection}"
        end
        original_words = query.downcase.scan(/[[:word:]]+/)
        leading_words = expected_query.downcase.scan(/[[:word:]]+/).first(original_words.size)
        expected_query = "#{query} #{expected_query}" unless leading_words == original_words
        expect(InteractiveSearchService).to have_received(:call).with(hash_including(expanded_query: expected_query)).at_least(:once)
      end
    end

    [nil, {}, { ai_terms: nil }, { ai_terms: 'poultry' }, { ai_terms: [123] }, { ai_terms: [''] }, 'invalid'].each do |expansion|
      it "keeps search working but skips ambiguous captures with expansion data #{expansion.inspect}" do
        response = described_class.new(q: 'chicken', expanded_query: 'chicken Fillet Frozen', query_expansion: expansion).call

        expect(response.fetch(:meta).fetch(:interactive_search)).not_to have_key(:query_expansion)
        expect(InteractiveSearchService).to have_received(:call).with(hash_including(expanded_query: 'chicken Fillet Frozen'))
        expect(SearchExport::JourneyProjection).not_to have_received(:record)
      end
    end

    context 'with conditional expansion' do
      before do
        allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(true)
        allow(AdminConfiguration).to receive(:integer_value).and_call_original
        allow(AdminConfiguration).to receive(:integer_value).with('expand_search_min_results').and_return(5)
      end

      ['chicken', 'chicken poultry'].each do |expanded|
        it "records only the expansion used when the expander returns #{expanded.inspect}" do
          allow(ExpandSearchQueryService).to receive(:call).and_return(
            ExpandSearchQueryService::Result.new(expanded_query: expanded, reason: nil),
          )

          response = described_class.new(q: 'chicken').call

          expected = expanded == 'chicken' ? [] : %w[poultry]
          expect(response.dig(:meta, :interactive_search, :query_expansion)).to eq(ai_terms: expected)
          expect(TradeTariffBackend.search_client).to have_received(:search).exactly(expected.empty? ? 1 : 2).times
        end
      end
    end

    it 'records only the added terms the tariff vocabulary supports' do
      allow(Search::ExpansionVocabulary).to receive(:lookup).and_return(
        Search::ExpansionVocabulary::Lookup.new(status: :ready, words: Set.new(%w[poultry meat]), generation: 'test'),
      )
      allow(ExpandSearchQueryService).to receive(:call).and_return(
        ExpandSearchQueryService::Result.new(
          expanded_query: 'chicken poultry meat zaptoxidinyl serum', reason: nil,
          added_terms: ['poultry meat', 'zaptoxidinyl serum']
        ),
      )

      response = described_class.new(q: 'chicken', request_id: 'expansion-journey').call

      expect(response.dig(:meta, :interactive_search, :query_expansion)).to eq(ai_terms: ['poultry meat'])
      expect(response.dig(:meta, :interactive_search, :expanded_query)).to eq('chicken poultry meat')
      expect(InteractiveSearchService).to have_received(:call)
        .with(hash_including(expanded_query: 'chicken poultry meat'))
    end

    context 'with structured model proposals' do
      before do
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
        allow(OpenaiClient).to receive(:call).and_return(
          'added_terms' => ['poultry meat', 'zaptoxidinyl serum'], 'reason' => 'trade terms',
        )
        allow(Search::ExpansionVocabulary).to receive(:lookup).and_return(
          Search::ExpansionVocabulary::Lookup.new(status: :ready, words: Set.new(%w[poultry meat]), generation: 'test'),
        )
      end

      it 'preserves reporting through caching and answers', :aggregate_failures do
        described_class.new(q: 'chicken', request_id: 'first-search').call
        response = described_class.new(q: 'chicken', request_id: 'cached-search').call
        # The frontend receives and returns JSON, not internal value objects.
        interactive = JSON.parse(JSON.generate(response)).fetch('meta').fetch('interactive_search')
        expect(interactive.fetch('expanded_query')).to eq('chicken poultry meat')
        expect(interactive.fetch('query_expansion')).to eq('ai_terms' => ['poultry meat'])

        allow(InteractiveSearchService).to receive(:call).and_return(nil)
        described_class.new(
          q: 'chicken', request_id: 'cached-search',
          expanded_query: interactive.fetch('expanded_query'),
          query_expansion: interactive.fetch('query_expansion'),
          answers: [{ question: 'Which kind?', options: %w[Fillet Frozen], answer: 'Fillet' }]
        ).call

        expect(OpenaiClient).to have_received(:call).once
        expect(Search::Instrumentation).to have_received(:evaluation_journey_recorded).with(
          hash_including(
            request_id: 'cached-search', query: 'chicken', expansion_terms: ['poultry meat'],
            trace_version: 'classification_evaluation_trace.v2',
            answers: [{ 'question' => 'Which kind?', 'options' => %w[Fillet Frozen], 'answer' => 'Fillet' }]
          ),
        ).once
        expect(InteractiveSearchService).to have_received(:call)
          .with(hash_including(expanded_query: 'chicken poultry meat Fillet'))
        expect(TradeTariffRequest.search_failures).to be_blank
      end

      it 'preserves the same response through queued search' do
        inputs = { q: 'chicken', request_id: 'same-journey', answers: [] }
        synchronous = described_class.new(inputs).call
        queued = QueuedSearch.create(
          params: inputs,
          context: { request_id: 'same-journey', request_source: 'frontend', as_of: Date.current.iso8601 },
        )

        QueuedSearchWorker.new.perform(queued.id)

        expect(queued.payload).to include(
          'status' => 'completed', 'response_status' => 200,
          'result' => JSON.parse(JSON.generate(synchronous))
        )
      ensure
        queued&.delete
      end

      it 'keeps vocabulary fallback eligible for reporting' do
        allow(Search::ExpansionVocabulary).to receive(:lookup).and_return(
          Search::ExpansionVocabulary::Lookup.new(status: :unavailable, words: Set.new, generation: nil),
        )
        allow(InteractiveSearchService).to receive(:call).and_return(nil)

        described_class.new(q: 'chicken', request_id: 'unavailable-vocabulary').call

        expect(Search::Instrumentation).to have_received(:evaluation_journey_recorded)
          .with(hash_including(request_id: 'unavailable-vocabulary', expansion_terms: []))
        expect(TradeTariffRequest.search_failures).to be_blank
      end
    end

    it 'combines carried AI terms with synonyms from the current retrieval only' do
      allow(AdminConfiguration).to receive(:option_value).with('expand_search_decider').and_return('v2')
      allow(Search::SynonymExpander).to receive(:added_terms).with('chicken poultry Fillet').and_return(['bird meat'])
      allow(Search::SynonymExpander).to receive(:call).with('chicken poultry Fillet').and_return('chicken poultry Fillet bird meat')

      response = described_class.new(
        q: 'chicken', expanded_query: 'chicken poultry', query_expansion: { ai_terms: %w[poultry] },
        answers: [{ question: 'Cut?', options: %w[Fillet Whole], answer: 'Fillet' }]
      ).call

      expect(response.dig(:meta, :interactive_search, :query_expansion)).to eq(ai_terms: %w[poultry])
      expect(SearchExport::JourneyProjection).to have_received(:record).with(hash_including(expansion_terms: ['poultry', 'bird meat']))
      expect(InteractiveSearchService).to have_received(:call).with(hash_including(expanded_query: 'chicken poultry Fillet'))
    end

    it 'preserves explicit empty expansion data with answer refinement disabled' do
      allow(AdminConfiguration).to receive(:enabled?).with('refine_search_with_answers_enabled').and_return(false)

      response = described_class.new(
        q: 'chicken', expanded_query: 'chicken', query_expansion: { 'ai_terms' => [] },
        answers: [{ question: 'Cut?', options: %w[Fillet Whole], answer: 'Fillet' }]
      ).call

      expect(response.dig(:meta, :interactive_search, :query_expansion)).to eq(ai_terms: [])
      expect(InteractiveSearchService).to have_received(:call).with(hash_including(expanded_query: 'chicken'))
      expect(SearchExport::JourneyProjection).to have_received(:record).with(hash_including(expansion_terms: []))
    end
  end
end
