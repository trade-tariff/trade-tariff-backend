require 'active_support/notifications'
require_relative '../timed_instrumentation'

module SelfTextGenerator
  module Instrumentation
  module_function

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{event_name}.self_text_generator", payload, &block)
    end

    def generation_started(total_chapters:)
      instrument('generation_started', total_chapters:)
    end

    def generation_completed
      instrument('generation_completed')
    end

    def chapter_started(chapter_sid:, chapter_code:)
      instrument('chapter_started', chapter_sid:, chapter_code:)
    end

    def chapter_completed(chapter_sid:, chapter_code:, &block)
      instrument('chapter_completed', chapter_sid:, chapter_code:, ai: nil, non_other_ai: nil, &block)
    end

    def chapter_failed(chapter_sid:, chapter_code:, error:)
      instrument(
        'chapter_failed',
        chapter_sid:,
        chapter_code:,
        error_class: error.class.name,
        error_message: error.message,
      )
    end

    def api_call(batch_size:, model:, chapter_code:, &block)
      TimedInstrumentation.call(
        instrumenter: method(:instrument),
        started_event: 'api_call_started',
        completed_event: 'api_call_completed',
        failed_event: 'api_call_failed',
        payload: { batch_size:, model:, chapter_code: },
        failed_payload: method(:http_status_payload), &block
      )
    end

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

    def embedding_api_call(batch_size:, model:, chapter_code:, &block)
      TimedInstrumentation.call(
        instrumenter: method(:instrument),
        started_event: 'embedding_api_call_started',
        completed_event: 'embedding_api_call_completed',
        failed_event: 'embedding_api_call_failed',
        payload: { batch_size:, model:, chapter_code: },
        failed_payload: method(:http_status_payload), &block
      )
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

    def http_status_payload(error)
      {
        http_status: if error.respond_to?(:http_status)
                       error.http_status
                     else
                       error.respond_to?(:response) ? error.response&.dig(:status) : nil
                     end,
      }
    end
  end
end
