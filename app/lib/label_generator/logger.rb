require 'active_support/log_subscriber'

module LabelGenerator
  class Logger < ActiveSupport::LogSubscriber
    def generation_started(event)
      info log_entry(
        event: 'generation_started',
        total_pages: event.payload[:total_pages],
        page_size: event.payload[:page_size],
        total_records: event.payload[:total_records],
      )
    end

    def generation_completed(event)
      info log_entry(
        event: 'generation_completed',
        total_pages: event.payload[:total_pages],
        duration_ms: event.duration.round(2),
      )
    end

    def page_started(event)
      debug log_entry(
        event: 'page_started',
        page_number: event.payload[:page_number],
        batch_size: event.payload[:batch_size],
      )
    end

    def page_completed(event)
      info log_entry(
        event: 'page_completed',
        page_number: event.payload[:page_number],
        labels_created: event.payload[:labels_created],
        labels_failed: event.payload[:labels_failed],
        duration_ms: event.duration.round(2),
      )
    end

    def page_failed(event)
      error log_entry(
        event: 'page_failed',
        page_number: event.payload[:page_number],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
        ai_response: event.payload[:ai_response],
        duration_ms: event.duration.round(2),
      )
    end

    def api_call_started(event)
      debug log_entry(
        event: 'api_call_started',
        page_number: event.payload[:page_number],
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
      )
    end

    def api_call_completed(event)
      info log_entry(
        event: 'api_call_completed',
        page_number: event.payload[:page_number],
        batch_size: event.payload[:batch_size],
        results_count: event.payload[:results_count],
        model: event.payload[:model],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def api_call_failed(event)
      error log_entry(
        event: 'api_call_failed',
        page_number: event.payload[:page_number],
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def label_saved(event)
      debug log_entry(
        event: 'label_saved',
        page_number: event.payload[:page_number],
        goods_nomenclature_sid: event.payload[:goods_nomenclature_sid],
        goods_nomenclature_item_id: event.payload[:goods_nomenclature_item_id],
        operation: event.payload[:operation],
      )
    end

    def label_save_failed(event)
      error log_entry(
        event: 'label_save_failed',
        page_number: event.payload[:page_number],
        goods_nomenclature_sid: event.payload[:goods_nomenclature_sid],
        goods_nomenclature_item_id: event.payload[:goods_nomenclature_item_id],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
        validation_errors: event.payload[:validation_errors],
      )
    end

    def label_not_found(event)
      warn log_entry(
        event: 'label_not_found',
        commodity_code: event.payload[:commodity_code],
        page_number: event.payload[:page_number],
      )
    end

    def scoring_started(event)
      info log_entry(
        event: 'scoring_started',
        total_records: event.payload[:total_records],
      )
    end

    def scoring_completed(event)
      info log_entry(
        event: 'scoring_completed',
        scored: event.payload[:scored],
        mean_description_score: event.payload[:mean_description_score],
        duration_ms: event.duration.round(2),
      )
    end

    def scoring_failed(event)
      error log_entry(
        event: 'scoring_failed',
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def embedding_api_call_started(event)
      debug log_entry(
        event: 'embedding_api_call_started',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
      )
    end

    def embedding_api_call_completed(event)
      info log_entry(
        event: 'embedding_api_call_completed',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def embedding_api_call_failed(event)
      error log_entry(
        event: 'embedding_api_call_failed',
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
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
        error_message: event.payload[:error_message],
      )
    end

    private

    def log_entry(data)
      data.merge(
        service: 'label_generator',
        timestamp: Time.current.iso8601,
      ).to_json
    end
  end
end

LabelGenerator::Logger.attach_to :label_generator unless Rails.env.test?
