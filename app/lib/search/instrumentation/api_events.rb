module Search
  module Instrumentation
    module ApiEvents
      def api_call(request_id:, model:, attempt_number:, iteration: nil, effective_query: nil, operation: 'interactive_search', emit_search_failed: true)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        instrument(
          'api_call_completed',
          {
            request_id:,
            search_type: 'interactive',
            model:,
            duration_ms: (duration * 1000).round(2),
            response_type: determine_response_type(result),
            attempt_number:,
            iteration:,
            effective_query:,
            operation:,
          }.merge(error_payload_for_result(result)),
        )

        result
      rescue StandardError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        instrument(
          'api_call_completed',
          {
            request_id:,
            search_type: 'interactive',
            model:,
            duration_ms: (duration * 1000).round(2),
            response_type: 'error',
            attempt_number:,
            iteration:,
            effective_query:,
            operation:,
          }.merge(truncate_error_payload(e.message)),
        )
        search_failed(request_id:, error_type: e.class.name, error_message: e.message, search_type: 'interactive') if emit_search_failed
        raise
      end

      def determine_response_type(result)
        return 'unknown' if result.nil?

        parsed = parse_result(result)
        return 'error' if parsed.is_a?(Hash) && parsed['error'].present?
        return 'answers' if parsed.is_a?(Hash) && parsed['answers'].present?
        return 'questions' if parsed.is_a?(Hash) && parsed['questions'].is_a?(Array) && parsed['questions'].any?
        return 'duplicate_validation' if parsed.is_a?(Hash) && [true, false].include?(parsed['duplicate'])

        'unknown'
      rescue StandardError
        'unknown'
      end

      def error_payload_for_result(result)
        parsed = parse_result(result)
        return {} unless parsed.is_a?(Hash) && parsed['error'].present?

        truncate_error_payload(parsed['error'])
      rescue StandardError
        {}
      end

      def parse_result(result)
        result.is_a?(String) ? ExtractBottomJson.call(result) : result
      end
    end
  end
end
