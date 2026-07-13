module LabelGenerator
  module Instrumentation
    module GenerationEvents
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

      def api_call(batch_size:, model:, page_number:, &block)
        TimedInstrumentation.call(
          instrumenter: method(:instrument),
          started_event: 'api_call_started',
          completed_event: 'api_call_completed',
          failed_event: 'api_call_failed',
          payload: { batch_size:, model:, page_number: },
          completed_payload: lambda { |result|
            {
              results_count: result.is_a?(Hash) ? Array.wrap(result['data']).size : 0,
              event_kind: 'label_generation',
            }.merge(AiUsage.payload_from(result))
          },
          failed_payload: lambda { |error|
            {
              error_message: AiUsage.safe_error_message(error),
              event_kind: 'label_generation',
            }.merge(AiUsage.payload_from_error(error))
          },
          &block
        )
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
    end
  end
end
