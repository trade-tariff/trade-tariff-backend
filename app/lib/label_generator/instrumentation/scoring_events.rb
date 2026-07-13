module LabelGenerator
  module Instrumentation
    module ScoringEvents
      def scoring_started(total_records:)
        instrument('scoring_started', total_records:)
      end

      def scoring_completed(&block)
        instrument(
          'scoring_completed',
          scored: nil,
          mean_description_score: nil,
          &block
        )
      end

      def scoring_failed(error:)
        instrument(
          'scoring_failed',
          error_class: error.class.name,
          error_message: error.message,
        )
      end

      def embedding_api_call(batch_size:, model:)
        instrument('embedding_api_call_started', batch_size:, model:)

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        instrument(
          'embedding_api_call_completed',
          {
            batch_size:,
            model:,
            duration_ms: (duration * 1000).round(2),
            event_kind: 'label_scoring_embedding',
          }.merge(AiUsage.payload_from(result)),
        )

        result
      rescue StandardError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        http_status = e.respond_to?(:response) ? e.response&.dig(:status) : nil

        instrument(
          'embedding_api_call_failed',
          {
            batch_size:,
            model:,
            error_class: e.class.name,
            error_message: AiUsage.safe_error_message(e),
            duration_ms: (duration * 1000).round(2),
            http_status:,
            event_kind: 'label_scoring_embedding',
          }.merge(AiUsage.payload_from_error(e)),
        )
        raise
      end
    end
  end
end
