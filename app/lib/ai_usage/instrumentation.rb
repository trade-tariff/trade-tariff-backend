require 'active_support/notifications'
require_relative 'logger'

module AiUsage
  module Instrumentation
  module_function

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{event_name}.ai_usage", payload, &block)
    end

    def api_call(event_kind:, model:, batch_size: nil, &block)
      call('api_call', event_kind:, batch_size:, model:, &block)
    end

    def embedding_api_call(event_kind:, batch_size:, model:, &block)
      call('embedding_api_call', event_kind:, batch_size:, model:, &block)
    end

    def embedding_api_retry(event_kind:, batch_size:, model:, attempt:, delay:, error:)
      instrument(
        'embedding_api_retry',
        event_kind:,
        batch_size:,
        model:,
        attempt:,
        delay:,
        error_class: error.class.name,
        error_message: AiUsage.safe_error_message(error),
      )
    end

    def call(event_prefix, event_kind:, batch_size:, model:)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      instrument(
        "#{event_prefix}_completed",
        event_payload(event_kind:, batch_size:, model:, duration:).merge(AiUsage.payload_from(result)),
      )
      result
    rescue StandardError => e
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      instrument(
        "#{event_prefix}_failed",
        event_payload(event_kind:, batch_size:, model:, duration:).merge(
          error_class: e.class.name,
          error_message: AiUsage.safe_error_message(e),
        ).merge(AiUsage.payload_from_error(e)),
      )
      raise
    end

    def event_payload(event_kind:, batch_size:, model:, duration:)
      {
        event_kind:,
        batch_size:,
        model:,
        duration_ms: (duration * 1000).round(2),
      }
    end
  end
end
