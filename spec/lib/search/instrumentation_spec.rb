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
  end

  describe '.question_returned' do
    it 'instruments the question_returned event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.question_returned(request_id: 'req-1', question_count: 2, attempt_number: 1)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'question_returned.search',
        request_id: 'req-1',
        question_count: 2,
        attempt_number: 1,
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
      )

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'answer_returned.search',
        request_id: 'req-1',
        answer_count: 3,
        confidence_levels: { 'strong' => 1, 'good' => 2 },
        attempt_number: 2,
      )
    end
  end

  describe '.search_completed' do
    it 'instruments the search_completed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.search_completed(
        request_id: 'req-1',
        query: 'horses',
        search_type: 'interactive',
        total_attempts: 2,
        total_questions: 1,
        final_result_type: 'answers',
        total_duration_ms: 1500.0,
        result_count: 3,
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
        search_type: 'interactive',
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
