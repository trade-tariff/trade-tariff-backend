RSpec.describe Search::Instrumentation do
  describe '.search_started' do
    it 'instruments the search_started event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.search_started(request_id: 'req-1', query: 'horses', search_type: 'interactive')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_started.search',
        request_id: 'req-1',
        query: 'horses',
        search_type: 'interactive',
      )
    end

    it 'uses the TradeTariffRequest request_id when the payload request_id is blank' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      TradeTariffRequest.request_id = 'current-request-id'

      described_class.search_started(request_id: nil, query: 'horses', search_type: 'interactive')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_started.search',
        request_id: 'current-request-id',
        query: 'horses',
        search_type: 'interactive',
      )
    end
  end

  describe '.search' do
    it 'fires search_started and search_completed around the block' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      result = described_class.search(request_id: 'req-1', query: 'horses', search_type: 'interactive') do
        ['the result', { result_count: 5 }]
      end

      expect(result).to eq('the result')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_started.search',
        request_id: 'req-1',
        query: 'horses',
        search_type: 'interactive',
      )
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_completed.search',
        hash_including(
          request_id: 'req-1',
          query: 'horses',
          search_type: 'interactive',
          result_count: 5,
          total_duration_ms: a_kind_of(Float),
        ),
      )
    end

    it 'emits search_failed and re-raises on error' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      expect {
        described_class.search(request_id: 'req-1', query: 'horses', search_type: 'classic') do
          raise Faraday::TimeoutError
        end
      }.to raise_error(Faraday::TimeoutError)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_started.search',
        hash_including(request_id: 'req-1'),
      )
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_failed.search',
        hash_including(
          request_id: 'req-1',
          error_type: 'Faraday::TimeoutError',
          search_type: 'classic',
        ),
      )
    end

    it 'passes completion payload through to search_completed' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.search(request_id: 'req-1', query: 'q', search_type: 'classic') do
        ['result', { result_count: 3, results_type: :fuzzy_search, max_score: 12.5 }]
      end

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_completed.search',
        hash_including(
          results_type: :fuzzy_search,
          max_score: 12.5,
        ),
      )
    end
  end

  describe '.query_expanded' do
    it 'instruments the query_expanded event with timing' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      expand_result = ExpandSearchQueryService::Result.new(expanded_query: 'equine animals', reason: 'colloquial')

      result = described_class.query_expanded(request_id: 'req-1', original_query: 'horses') { expand_result }

      expect(result).to eq(expand_result)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'query_expanded.search',
        hash_including(
          request_id: 'req-1',
          original_query: 'horses',
          expanded_query: 'equine animals',
          reason: 'colloquial',
        ),
      )
    end

    it 'measures duration' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      expand_result = ExpandSearchQueryService::Result.new(expanded_query: 'horses', reason: nil)

      described_class.query_expanded(request_id: 'req-1', original_query: 'horses') { expand_result }

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'query_expanded.search',
        hash_including(duration_ms: a_kind_of(Float)),
      )
    end
  end

  describe '.query_refined' do
    it 'instruments the query_refined event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      result = described_class.query_refined(
        request_id: 'req-1',
        original_query: 'handbag',
        refined_query: 'handbag Leather',
        answer_count: 1,
      ) { 'handbag Leather' }

      expect(result).to eq('handbag Leather')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'query_refined.search',
        request_id: 'req-1',
        original_query: 'handbag',
        refined_query: 'handbag Leather',
        answer_count: 1,
      )
    end
  end

  describe '.query_expansion_decided' do
    it 'instruments the query_expansion_decided event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.query_expansion_decided(
        request_id: 'req-1',
        query: 'CBD oil',
        expand: true,
        reason: 'non_word_token',
        result_count: 3,
        max_score: 4.5,
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'query_expansion_decided.search',
        request_id: 'req-1',
        query: 'CBD oil',
        expand: true,
        reason: 'non_word_token',
        result_count: 3,
        max_score: 4.5,
      )
    end
  end

  describe '.api_call' do
    it 'instruments the api_call_completed event and returns the result' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      result = described_class.api_call(request_id: 'req-1', model: 'gpt-4', attempt_number: 1) { 'ai response' }

      expect(result).to eq('ai response')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'api_call_completed.search',
        hash_including(
          request_id: 'req-1',
          model: 'gpt-4',
          attempt_number: 1,
          duration_ms: a_kind_of(Float),
        ),
      )
    end

    it 'instruments and re-raises on error' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      expect {
        described_class.api_call(request_id: 'req-1', model: 'gpt-4', attempt_number: 1) { raise Faraday::TimeoutError }
      }.to raise_error(Faraday::TimeoutError)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'api_call_completed.search',
        hash_including(response_type: 'error'),
      )
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_failed.search',
        hash_including(error_type: 'Faraday::TimeoutError'),
      )
    end

    it 'includes truncated error details when the model returns an error payload' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      error_message = 'x' * 550

      described_class.api_call(request_id: 'req-1', model: 'gpt-4', attempt_number: 1) do
        { 'error' => error_message }
      end

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'api_call_completed.search',
        hash_including(
          response_type: 'error',
          error_message: ('x' * 500),
          error_message_truncated: true,
        ),
      )
    end
  end

  describe '.exact_match_selected' do
    it 'instruments compact exact match result details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      result = GoodsNomenclatureResult.new(
        id: 1,
        goods_nomenclature_item_id: '0101210000',
        goods_nomenclature_sid: 1,
        producline_suffix: '80',
        goods_nomenclature_class: 'Commodity',
        description: 'Horse',
        formatted_description: 'Horse',
        self_text: 'Generated self text',
        classification_description: 'Horse',
        full_description: 'Horse',
        heading_description: nil,
        declarable: true,
        score: nil,
        confidence: 'strong',
      )

      described_class.exact_match_selected(
        request_id: 'req-1',
        search_type: 'interactive',
        query: 'horse',
        match_source: 'search_reference',
        matched_value: 'horse',
        result: result,
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'exact_match_selected.search',
        hash_including(
          request_id: 'req-1',
          search_type: 'interactive',
          match_source: 'search_reference',
          target_id: '0101210000',
          target_endpoint: 'commodities',
          goods_nomenclature_sid: 1,
          details: hash_including(has_self_text: true, self_text_id: 1, label_id: 1),
        ),
      )
    end

    it 'uses the classic entity route target for exact tariff entities' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      heading = Heading.call(goods_nomenclature_item_id: '0101000000', goods_nomenclature_sid: 1)

      described_class.exact_match_selected(
        request_id: 'req-1',
        search_type: 'classic',
        query: '0101',
        match_source: 'goods_nomenclature',
        matched_value: '0101',
        result: heading,
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'exact_match_selected.search',
        hash_including(
          target_type: 'Heading',
          target_endpoint: 'headings',
          target_id: '0101',
          goods_nomenclature_item_id: '0101000000',
        ),
      )
    end
  end

  describe '.fuzzy_results_returned' do
    it 'instruments compact grouped fuzzy result details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.fuzzy_results_returned(
        request_id: 'req-1',
        query: 'horse',
        results: {
          goods_nomenclature_match: {
            'chapters' => [
              { '_score' => 12.5, '_source' => { 'goods_nomenclature_item_id' => '0100000000', 'goods_nomenclature_sid' => 1 } },
            ],
          },
          reference_match: {
            'headings' => [
              { '_score' => 10.1, '_source' => { 'reference_class' => 'Heading', 'reference' => { 'id' => 2, 'title' => 'Equine animals', 'goods_nomenclature_item_id' => '0101000000' } } },
            ],
          },
        },
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'fuzzy_results_returned.search',
        hash_including(
          request_id: 'req-1',
          search_type: 'classic',
          result_count: 2,
          details: {
            goods_nomenclature_match: {
              'chapters' => [
                hash_including(target_endpoint: 'chapters', target_id: '01', goods_nomenclature_class: 'Chapter'),
              ],
            },
            reference_match: {
              'headings' => [
                hash_including(target_endpoint: 'headings', target_id: '0101', goods_nomenclature_class: 'Heading', reference_title: 'Equine animals'),
              ],
            },
          },
        ),
      )
    end

    it 'counts all fuzzy results while truncating logged details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      hits = Array.new(60) do |index|
        {
          '_score' => 12.5,
          '_source' => {
            'goods_nomenclature_item_id' => "01012100#{index.to_s.rjust(2, '0')}",
            'goods_nomenclature_sid' => index,
            'goods_nomenclature_class' => 'Commodity',
          },
        }
      end

      described_class.fuzzy_results_returned(
        request_id: 'req-1',
        query: 'horse',
        results: { goods_nomenclature_match: { 'commodities' => hits } },
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'fuzzy_results_returned.search',
        hash_including(
          result_count: 60,
          details: hash_including(
            goods_nomenclature_match: hash_including('commodities' => have_attributes(size: 50)),
          ),
        ),
      )
    end
  end

  describe '.interactive_configuration_used' do
    it 'instruments configuration details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.interactive_configuration_used(
        request_id: 'req-1',
        query: 'horse',
        configuration: { retrieval_method: 'hybrid', rrf_k: 60 },
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'interactive_configuration_used.search',
        hash_including(search_type: 'interactive', details: { retrieval_method: 'hybrid', rrf_k: 60 }),
      )
    end
  end

  describe '.retrieval_results_returned' do
    it 'instruments compact retrieval result details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      result = GoodsNomenclatureResult.new(
        id: 1,
        goods_nomenclature_item_id: '0101210000',
        goods_nomenclature_sid: 1,
        producline_suffix: '80',
        goods_nomenclature_class: 'Commodity',
        description: 'Horse',
        formatted_description: 'Horse',
        self_text: nil,
        classification_description: 'Horse',
        full_description: 'Horse',
        heading_description: nil,
        declarable: true,
        score: 12.5,
        confidence: nil,
      )

      described_class.retrieval_results_returned(
        request_id: 'req-1',
        query: 'horse',
        search_type: 'interactive',
        retrieval_method: 'hybrid',
        stage: 'after_rrf',
        results: [result],
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'retrieval_results_returned.search',
        hash_including(
          retrieval_method: 'hybrid',
          stage: 'after_rrf',
          result_count: 1,
          details: { results: [hash_including(goods_nomenclature_item_id: '0101210000', score: 12.5)] },
        ),
      )
    end
  end

  describe '.question_returned' do
    it 'instruments the question_returned event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.question_returned(request_id: 'req-1', question_count: 2, attempt_number: 1, questions: [{ question: 'Material?' }])

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'question_returned.search',
        request_id: 'req-1',
        question_count: 2,
        attempt_number: 1,
        details: { questions: [{ question: 'Material?' }] },
      )
    end
  end

  describe '.answer_returned' do
    it 'instruments the answer_returned event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.answer_returned(
        request_id: 'req-1',
        answer_count: 3,
        confidence_levels: { 'strong' => 1, 'good' => 2 },
        attempt_number: 2,
        answers: [{ commodity_code: '0101210000', confidence: 'strong' }],
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'answer_returned.search',
        request_id: 'req-1',
        answer_count: 3,
        confidence_levels: { 'strong' => 1, 'good' => 2 },
        attempt_number: 2,
        details: { answers: [{ commodity_code: '0101210000', confidence: 'strong' }] },
      )
    end
  end

  describe '.description_intercept_checked' do
    it 'instruments an unmatched description intercept check' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.description_intercept_checked(
        request_id: 'req-1',
        query: 'horses',
        description_intercept: nil,
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'description_intercept_checked.search',
        request_id: 'req-1',
        query: 'horses',
        matched: false,
      )
    end

    it 'instruments a matched description intercept check with low-cardinality fields' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      intercept = double(
        term: 'gift',
        excluded: true,
        filtering?: true,
        filter_prefixes_array: %w[9503 9504],
        guidance_level: 'warning',
        guidance_location: 'interstitial',
        escalate_to_webchat: true,
      )

      described_class.description_intercept_checked(
        request_id: 'req-1',
        query: 'gift',
        description_intercept: intercept,
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'description_intercept_checked.search',
        request_id: 'req-1',
        query: 'gift',
        matched: true,
        term: 'gift',
        excluded: true,
        filtering: true,
        filter_prefix_count: 2,
        guidance_level: 'warning',
        guidance_location: 'interstitial',
        escalate_to_webchat: true,
      )
    end
  end

  describe '.search_completed' do
    it 'instruments the search_completed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      intercept = double(
        term: 'gift',
        excluded: false,
        filtering?: true,
        filter_prefixes_array: %w[9503 9504],
        guidance_level: 'info',
        guidance_location: 'results',
        escalate_to_webchat: false,
      )

      described_class.search_completed(
        request_id: 'req-1',
        query: 'horses',
        search_type: 'interactive',
        total_attempts: 2,
        total_questions: 1,
        final_result_type: 'answers',
        total_duration_ms: 1500.0,
        result_count: 3,
        description_intercept: intercept,
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_completed.search',
        request_id: 'req-1',
        query: 'horses',
        search_type: 'interactive',
        total_attempts: 2,
        total_questions: 1,
        final_result_type: 'answers',
        total_duration_ms: 1500.0,
        result_count: 3,
        description_intercept_matched: true,
        description_intercept_term: 'gift',
        description_intercept_excluded: false,
        description_intercept_filtering: true,
        description_intercept_filter_prefix_count: 2,
        description_intercept_guidance_level: 'info',
        description_intercept_guidance_location: 'results',
        description_intercept_escalate_to_webchat: false,
      )
    end

    it 'includes truncated error details when provided' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.search_completed(
        request_id: 'req-1',
        query: 'horses',
        search_type: 'interactive',
        total_attempts: 2,
        total_questions: 1,
        final_result_type: 'error',
        total_duration_ms: 1500.0,
        result_count: 3,
        error_message: 'x' * 550,
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_completed.search',
        hash_including(
          error_message: ('x' * 500),
          error_message_truncated: true,
        ),
      )
    end
  end

  describe '.retrieval_leg_completed' do
    it 'includes truncated error details when provided' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.retrieval_leg_completed(
        request_id: 'req-1',
        leg: :vector,
        duration_ms: 123.4,
        result_count: 0,
        status: 'error',
        error_message: 'x' * 550,
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'retrieval_leg_completed.search',
        hash_including(
          error_message: ('x' * 500),
          error_message_truncated: true,
        ),
      )
    end
  end

  describe '.result_selected' do
    it 'instruments the result_selected event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.result_selected(
        request_id: 'req-1',
        goods_nomenclature_item_id: '4202210000',
        goods_nomenclature_class: 'Commodity',
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'result_selected.search',
        request_id: 'req-1',
        goods_nomenclature_item_id: '4202210000',
        goods_nomenclature_class: 'Commodity',
      )
    end
  end

  describe '.search_failed' do
    it 'instruments the search_failed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.search_failed(
        request_id: 'req-1',
        error_type: 'Faraday::TimeoutError',
        error_message: 'connection timed out',
        search_type: 'interactive',
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_failed.search',
        request_id: 'req-1',
        error_type: 'Faraday::TimeoutError',
        error_message: 'connection timed out',
        error_message_truncated: false,
        search_type: 'interactive',
      )
    end

    it 'truncates long error messages' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.search_failed(
        request_id: 'req-1',
        error_type: 'Faraday::TimeoutError',
        error_message: 'x' * 550,
        search_type: 'interactive',
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'search_failed.search',
        hash_including(
          error_message: ('x' * 500),
          error_message_truncated: true,
        ),
      )
    end
  end

  describe '.determine_response_type' do
    it 'returns "answers" for answer responses' do
      expect(described_class.determine_response_type('{"answers": [{"code": "123"}]}')).to eq('answers')
    end

    it 'returns "questions" for question responses' do
      expect(described_class.determine_response_type('{"questions": [{"question": "What?"}]}')).to eq('questions')
    end

    it 'returns "error" for error responses' do
      expect(described_class.determine_response_type('{"error": "something went wrong"}')).to eq('error')
    end

    it 'returns "unknown" for nil' do
      expect(described_class.determine_response_type(nil)).to eq('unknown')
    end

    it 'returns "unknown" for unrecognized responses' do
      expect(described_class.determine_response_type('{"something_else": true}')).to eq('unknown')
    end
  end
end
