module SelfTextGenerator
  module Instrumentation
    module ScoringEvents
      def scoring_started(chapter_code:, total_records:)
        instrument('scoring_started', chapter_code:, total_records:)
      end

      def scoring_completed(chapter_code:, &block)
        instrument(
          'scoring_completed',
          chapter_code:,
          eu_matched: nil,
          embeddings_generated: nil,
          mean_similarity: nil,
          mean_coherence: nil,
          &block
        )
      end

      def scoring_failed(chapter_code:, error:)
        instrument(
          'scoring_failed',
          chapter_code:,
          error_class: error.class.name,
          error_message: error.message,
        )
      end

      def embedding_api_call(batch_size:, model:, chapter_code:)
        instrument('embedding_api_call_started', batch_size:, model:, chapter_code:)

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        instrument(
          'embedding_api_call_completed',
          {
            batch_size:,
            model:,
            chapter_code:,
            duration_ms: (duration * 1000).round(2),
            event_kind: 'self_text_scoring_embedding',
          }.merge(AiUsage.payload_from(result)),
        )

        result
      rescue StandardError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        http_status = if e.respond_to?(:http_status)
                        e.http_status
                      else
                        e.respond_to?(:response) ? e.response&.dig(:status) : nil
                      end

        instrument(
          'embedding_api_call_failed',
          {
            batch_size:,
            model:,
            chapter_code:,
            error_class: e.class.name,
            error_message: AiUsage.safe_error_message(e),
            duration_ms: (duration * 1000).round(2),
            http_status:,
            event_kind: 'self_text_scoring_embedding',
          }.merge(AiUsage.payload_from_error(e)),
        )
        raise
      end

      def embedding_api_retry(attempt:, delay:, error:)
        instrument(
          'embedding_api_retry',
          attempt:,
          delay:,
          error_class: error.class.name,
          error_message: error.message,
        )
      end

      def reindex_started
        instrument('reindex_started')
      end

      def reindex_completed
        instrument('reindex_completed')
      end
    end
  end
end
