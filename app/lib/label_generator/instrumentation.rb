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

    def coverage_snapshot(total_goods_nomenclatures:, total_labels:)
      missing_labels = total_goods_nomenclatures - total_labels
      coverage_percent = total_goods_nomenclatures.positive? ? (total_labels * 100.0 / total_goods_nomenclatures).round(2) : 0.0

      instrument(
        'coverage_snapshot',
        total_goods_nomenclatures:,
        total_labels:,
        coverage_percent:,
        missing_labels:,
      )

      publish_coverage_metrics(total_labels:, missing_labels:, coverage_percent:)
    end

    def publish_coverage_metrics(total_labels:, missing_labels:, coverage_percent:)
      return if Rails.env.test?
      return unless defined?(Aws::CloudWatch::Client)

      client = Aws::CloudWatch::Client.new
      namespace = "LabelGenerator/#{Rails.env}"

      client.put_metric_data(
        namespace:,
        metric_data: [
          { metric_name: 'TotalLabels', value: total_labels, unit: 'Count' },
          { metric_name: 'MissingLabels', value: missing_labels, unit: 'Count' },
          { metric_name: 'CoveragePercent', value: coverage_percent, unit: 'Percent' },
        ],
      )
    rescue StandardError => e
      Rails.logger.warn "Failed to publish coverage metrics: #{e.message}"
    end
  end
end
