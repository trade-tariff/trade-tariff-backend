require 'active_support/notifications'

module LabelGenerator
  module Instrumentation
    module_function

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{event_name}.label_generator", payload, &block)
    end

    def generation_started(total_pages:, page_size:, total_records:)
      instrument('generation_started', total_pages:, page_size:, total_records:)
    end

    def generation_completed(total_pages:, &block)
      instrument('generation_completed', total_pages:, &block)
    end

    def page_started(page_number:, batch_size:)
      instrument('page_started', page_number:, batch_size:)
    end

    def page_completed(page_number:, &block)
      instrument('page_completed', page_number:, labels_created: 0, labels_failed: 0, &block)
    end

    def page_failed(page_number:, error:, ai_response: nil, &block)
      instrument(
        'page_failed',
        page_number:,
        error_class: error.class.name,
        error_message: error.message,
        ai_response: ai_response&.to_json,
        &block
      )
    end

    def api_call(batch_size:, model:, page_number:)
      instrument('api_call_started', batch_size:, model:, page_number:)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      results_count = result.is_a?(Hash) ? Array.wrap(result['data']).size : 0

      instrument(
        'api_call_completed',
        batch_size:,
        model:,
        page_number:,
        results_count:,
        duration_ms: (duration * 1000).round(2),
      )

      result
    rescue StandardError => e
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      instrument(
        'api_call_failed',
        batch_size:,
        model:,
        page_number:,
        error_class: e.class.name,
        error_message: e.message,
        duration_ms: (duration * 1000).round(2),
      )
      raise
    end

    def label_saved(label, page_number:)
      instrument(
        'label_saved',
        goods_nomenclature_sid: label.goods_nomenclature_sid,
        goods_nomenclature_item_id: label.goods_nomenclature_item_id,
        operation: label[:operation],
        page_number:,
      )
    end

    def label_save_failed(label, error, page_number:)
      instrument(
        'label_save_failed',
        goods_nomenclature_sid: label.goods_nomenclature_sid,
        goods_nomenclature_item_id: label.goods_nomenclature_item_id,
        error_class: error.class.name,
        error_message: error.message,
        validation_errors: label.errors.to_h,
        page_number:,
      )
    end

    def label_not_found(commodity_code:, page_number:)
      instrument('label_not_found', commodity_code:, page_number:)
    end

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
        batch_size:,
        model:,
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
  end
end
