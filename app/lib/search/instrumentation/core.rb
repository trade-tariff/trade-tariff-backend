module Search
  module Instrumentation
    module Core
      def instrument(event_name, payload = {}, &block)
        ActiveSupport::Notifications.instrument("#{event_name}.search", with_request_context(payload), &block)
      end

      def search_started(request_id:, query:, search_type:)
        instrument('search_started', request_id:, query:, search_type:)
      end

      def search(request_id:, query:, search_type:)
        TradeTariffRequest.set(search_type:) do
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
      end

      def search_failed(request_id:, error_type:, error_message:, search_type:)
        instrument(
          'search_failed',
          {
            request_id:,
            error_type:,
            search_type:,
            search_degraded: true,
          }.merge(truncate_error_payload(error_message)),
        )
      end

      def search_stage_failed(request_id:, search_type:, failure_code:, error_type:, error_message:, operation: nil)
        TradeTariffRequest.record_search_failure(failure_code)
        instrument(
          'search_stage_failed',
          {
            request_id:, search_type:, failure_code:, error_type:, operation:
          }.compact.merge(truncate_error_payload(error_message)),
        )
      end
    end
  end
end
