module Search
  module Instrumentation
    module QueryEvents
      def query_expanded(request_id:, original_query:)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        instrument(
          'query_expanded',
          request_id:,
          search_type: 'interactive',
          original_query:,
          expanded_query: result.expanded_query,
          reason: result.reason,
          duration_ms: (duration * 1000).round(2),
        )

        result
      end

      def query_refined(request_id:, original_query:, refined_query:, answer_count:, base_query: original_query, effective_query: refined_query, added_answers: [], iteration: nil)
        result = yield
        instrument(
          'query_refined',
          request_id:,
          search_type: 'interactive',
          base_query:,
          original_query:,
          refined_query:,
          effective_query:,
          answer_count:,
          added_answers:,
          iteration:,
        )
        result
      end

      def query_expansion_decided(request_id:, query:, expand:, reason:, decider_version:, result_count:, max_score:)
        instrument(
          'query_expansion_decided',
          request_id:,
          search_type: 'interactive',
          query:,
          expand:,
          reason:,
          decider_version:,
          result_count:,
          max_score:,
        )
      end

      def query_expansion_timed_out(request_id:, timeout_ms:, elapsed_ms:, model:, fallback_outcome:)
        instrument(
          'query_expansion_timed_out',
          request_id:,
          search_type: 'interactive',
          timeout_ms:,
          elapsed_ms:,
          model:,
          fallback_outcome:,
        )
      end

      def duplicate_question_guard_checked(request_id:, attempt_number:, allowed:, duplicate:, suspicious:, signals:, reason:, iteration: nil, effective_query: nil, duplicate_of_question: nil, duplicate_of_answer: nil)
        reason_payload = truncate_reason_payload(reason)

        instrument(
          'duplicate_question_guard_checked',
          request_id:,
          search_type: 'interactive',
          attempt_number:,
          iteration:,
          effective_query:,
          allowed:,
          duplicate:,
          suspicious:,
          signals:,
          reason: reason_payload[:reason],
          reason_truncated: reason_payload[:reason_truncated],
          duplicate_of_question:,
          duplicate_of_answer:,
        )
      end
    end
  end
end
