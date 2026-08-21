module TariffSynchronizer
  module Import
    class OperationTracker
      def initialize(operation_keys:, publish_notifications: true)
        @metrics = OperationMetrics.new(operation_keys)
        @publish_notifications = publish_notifications
      end

      def track(event_name, mapper:, operation:, count:, record: nil)
        started_at = monotonic_now
        begin
          result = yield
        ensure
          duration = monotonic_now - started_at
          record_operation(event_name, mapper:, operation:, count:, duration:, record:)
        end

        result
      end

      def record(event_name, mapper:, operation:, count:, record: nil)
        record_operation(event_name, mapper:, operation:, count:, duration: 0, record:)
      end

      delegate :result, to: :@metrics

    private

      def record_operation(event_name, mapper:, operation:, count:, duration:, record:)
        metadata = {
          mapping_path: (mapper.mapping_path if mapper.respond_to?(:mapping_path)),
          record_identifier: record&.identification,
        }

        @metrics.record(operation:, entity_class: mapper.entity_class, count:, duration:, metadata:)
        publish(event_name, mapper:, operation:, count:, record:)
      end

      def publish(event_name, mapper:, operation:, count:, record: nil)
        return unless @publish_notifications

        payload = { mapper:, operation:, count: }
        payload[:record] = record if record

        ActiveSupport::Notifications.instrument(event_name, payload)
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
