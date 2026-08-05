require 'active_support/notifications'

module Notifications
  module Instrumentation
  module_function

    def instrument(event_name, payload = {})
      ActiveSupport::Notifications.instrument("#{event_name}.notifications", payload)
    end

    def send_skipped(pipeline:, identifier:, reason:)
      instrument('send_skipped', pipeline:, identifier:, reason:)
    end

    def enqueue_retrying(pipeline:, item:, attempt:, error_class:, error_message:)
      instrument('enqueue_retrying', pipeline:, item:, attempt:, error_class:, error_message:)
    end

    def enqueue_failed(pipeline:, items:, attempts:)
      instrument('enqueue_failed', pipeline:, items:, attempts:)
    end

    def delivery_failed(pipeline:, identifier:, notification_uuid:, status:)
      instrument('delivery_failed', pipeline:, identifier:, notification_uuid:, status:)
    end
  end
end
