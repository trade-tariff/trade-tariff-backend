require 'active_support/log_subscriber'

module SelfTextGenerator
  class Logger < ActiveSupport::LogSubscriber
    def generation_started(event)
      info log_entry(
        event: 'generation_started',
        total_chapters: event.payload[:total_chapters],
      )
    end

    def generation_completed(_event)
      info log_entry(
        event: 'generation_completed',
      )
    end

    def chapter_started(event)
      debug log_entry(
        event: 'chapter_started',
        chapter_sid: event.payload[:chapter_sid],
        chapter_code: event.payload[:chapter_code],
      )
    end

    def chapter_completed(event)
      info log_entry(
        event: 'chapter_completed',
        chapter_sid: event.payload[:chapter_sid],
        chapter_code: event.payload[:chapter_code],
        mechanical: event.payload[:mechanical],
        ai: event.payload[:ai],
        duration_ms: event.duration.round(2),
      )
    end

    def chapter_failed(event)
      error log_entry(
        event: 'chapter_failed',
        chapter_sid: event.payload[:chapter_sid],
        chapter_code: event.payload[:chapter_code],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def api_call_started(event)
      debug log_entry(
        event: 'api_call_started',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        chapter_code: event.payload[:chapter_code],
      )
    end

    def api_call_completed(event)
      info log_entry(
        event: 'api_call_completed',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        chapter_code: event.payload[:chapter_code],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def api_call_failed(event)
      error log_entry(
        event: 'api_call_failed',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        chapter_code: event.payload[:chapter_code],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
        duration_ms: event.payload[:duration_ms],
        http_status: event.payload[:http_status],
      )
    end

    def scoring_started(event)
      debug log_entry(
        event: 'scoring_started',
        chapter_code: event.payload[:chapter_code],
        total_records: event.payload[:total_records],
      )
    end

    def scoring_completed(event)
      info log_entry(
        event: 'scoring_completed',
        chapter_code: event.payload[:chapter_code],
        eu_matched: event.payload[:eu_matched],
        embeddings_generated: event.payload[:embeddings_generated],
        mean_similarity: event.payload[:mean_similarity],
        mean_coherence: event.payload[:mean_coherence],
        duration_ms: event.duration.round(2),
      )
    end

    def scoring_failed(event)
      error log_entry(
        event: 'scoring_failed',
        chapter_code: event.payload[:chapter_code],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def embedding_api_call_started(event)
      debug log_entry(
        event: 'embedding_api_call_started',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        chapter_code: event.payload[:chapter_code],
      )
    end

    def embedding_api_call_completed(event)
      info log_entry(
        event: 'embedding_api_call_completed',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        chapter_code: event.payload[:chapter_code],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def embedding_api_call_failed(event)
      error log_entry(
        event: 'embedding_api_call_failed',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        chapter_code: event.payload[:chapter_code],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
        duration_ms: event.payload[:duration_ms],
        http_status: event.payload[:http_status],
      )
    end

    def embedding_api_retry(event)
      warn log_entry(
        event: 'embedding_api_retry',
        attempt: event.payload[:attempt],
        delay: event.payload[:delay],
        error_class: event.payload[:error_class],
      )
    end

    def reindex_started(_event)
      info log_entry(event: 'reindex_started')
    end

    def reindex_completed(_event)
      info log_entry(event: 'reindex_completed')
    end

    private

    def log_entry(data)
      data.merge(
        service: 'self_text_generator',
        timestamp: Time.current.iso8601,
      ).to_json
    end
  end
end

SelfTextGenerator::Logger.attach_to :self_text_generator unless Rails.env.test?
