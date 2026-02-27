require 'active_support/notifications'

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

    def api_call(batch_size:, model:, chapter_code:)
      instrument('api_call_started', batch_size:, model:, chapter_code:)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      instrument(
        'api_call_completed',
        batch_size:,
        model:,
        chapter_code:,
        duration_ms: (duration * 1000).round(2),
      )

      result
    rescue StandardError => e
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      http_status = e.respond_to?(:response) ? e.response&.dig(:status) : nil

      instrument(
        'api_call_failed',
        batch_size:,
        model:,
        chapter_code:,
        error_class: e.class.name,
        error_message: e.message,
        duration_ms: (duration * 1000).round(2),
        http_status:,
      )
      raise
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

    def embedding_api_call(batch_size:, model:, chapter_code:)
      instrument('embedding_api_call_started', batch_size:, model:, chapter_code:)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      instrument(
        'embedding_api_call_completed',
        batch_size:,
        model:,
        chapter_code:,
        duration_ms: (duration * 1000).round(2),
      )

      result
    rescue StandardError => e
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      http_status = e.respond_to?(:response) ? e.response&.dig(:status) : nil

      instrument(
        'embedding_api_call_failed',
        batch_size:,
        model:,
        chapter_code:,
        error_class: e.class.name,
        error_message: e.message,
        duration_ms: (duration * 1000).round(2),
        http_status:,
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
