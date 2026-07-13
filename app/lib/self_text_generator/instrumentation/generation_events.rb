module SelfTextGenerator
  module Instrumentation
    module GenerationEvents
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

      def api_call(batch_size:, model:, chapter_code:, event_kind: 'self_text_generation_ai', &block)
        TimedInstrumentation.call(
          instrumenter: method(:instrument),
          started_event: 'api_call_started',
          completed_event: 'api_call_completed',
          failed_event: 'api_call_failed',
          payload: { batch_size:, model:, chapter_code: },
          completed_payload: lambda { |result|
            { event_kind: }.merge(AiUsage.payload_from(result))
          },
          failed_payload: lambda { |error|
            http_status = if error.respond_to?(:http_status)
                            error.http_status
                          else
                            error.respond_to?(:response) ? error.response&.dig(:status) : nil
                          end
            {
              error_message: AiUsage.safe_error_message(error),
              http_status:,
              event_kind:,
            }.merge(AiUsage.payload_from_error(error))
          },
          &block
        )
      end
    end
  end
end
