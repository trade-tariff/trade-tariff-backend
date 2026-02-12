require 'active_support/notifications'

module Search
  module Instrumentation
    module_function

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{event_name}.search", payload, &block)
    end

    def search_started(request_id:, query:, search_type:)
      instrument('search_started', request_id:, query:, search_type:)
    end

    def search(request_id:, query:, search_type:)
      search_started(request_id:, query:, search_type:)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result, completion_payload = yield

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
      search_completed(request_id:, query:, search_type:, total_duration_ms: duration_ms, **(completion_payload || {}))

      result
    rescue StandardError => e
      search_failed(request_id:, error_type: e.class.name, error_message: e.message, search_type:)
      raise
    end

    def query_expanded(request_id:, original_query:)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      instrument(
        'query_expanded',
        request_id:,
        original_query:,
        expanded_query: result.expanded_query,
        reason: result.reason,
        duration_ms: (duration * 1000).round(2),
      )

      result
    end

    def api_call(request_id:, model:, attempt_number:)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      instrument(
        'api_call_completed',
        request_id:,
        model:,
        duration_ms: (duration * 1000).round(2),
        response_type: determine_response_type(result),
        attempt_number:,
      )

      result
    rescue StandardError => e
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      instrument(
        'api_call_completed',
        request_id:,
        model:,
        duration_ms: (duration * 1000).round(2),
        response_type: 'error',
        attempt_number:,
      )
      search_failed(request_id:, error_type: e.class.name, error_message: e.message, search_type: 'interactive')
      raise
    end

    def question_returned(request_id:, question_count:, attempt_number:)
      instrument('question_returned', request_id:, question_count:, attempt_number:)
    end

    def answer_returned(request_id:, answer_count:, confidence_levels:, attempt_number:)
      instrument('answer_returned', request_id:, answer_count:, confidence_levels:, attempt_number:)
    end

    def search_completed(request_id:, search_type:, total_duration_ms:, result_count:, query: nil, total_attempts: nil, total_questions: nil, final_result_type: nil, results_type: nil, max_score: nil)
      payload = {
        request_id:,
        query:,
        search_type:,
        total_attempts:,
        total_questions:,
        final_result_type:,
        total_duration_ms:,
        result_count:,
      }
      payload[:results_type] = results_type if results_type
      payload[:max_score] = max_score if max_score
      instrument('search_completed', payload)
    end

    def result_selected(request_id:, goods_nomenclature_item_id:, goods_nomenclature_class:)
      instrument('result_selected', request_id:, goods_nomenclature_item_id:, goods_nomenclature_class:)
    end

    def search_failed(request_id:, error_type:, error_message:, search_type:)
      instrument('search_failed', request_id:, error_type:, error_message:, search_type:)
    end

    def determine_response_type(result)
      return 'unknown' if result.nil?

      parsed = result.is_a?(String) ? ExtractBottomJson.call(result) : result
      return 'error' if parsed.is_a?(Hash) && parsed['error'].present?
      return 'answers' if parsed.is_a?(Hash) && parsed['answers'].present?
      return 'questions' if parsed.is_a?(Hash) && parsed['questions'].is_a?(Array) && parsed['questions'].any?

      'unknown'
    rescue StandardError
      'unknown'
    end
  end
end
