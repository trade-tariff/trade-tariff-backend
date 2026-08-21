module TariffSynchronizer
  module Import
    class OperationMetrics
      def initialize(operation_keys)
        @operations = operation_keys.index_with { { count: 0, duration: 0 } }
        @total_count = 0
        @total_duration = 0
      end

      def record(operation:, entity_class:, count:, duration:, metadata: {})
        return unless count.positive?

        operation_bucket = @operations.fetch(operation)
        operation_bucket[:count] += count
        operation_bucket[:duration] += duration

        entity_bucket = (operation_bucket[entity_class] ||= { count: 0, duration: 0 })
        entity_bucket[:count] += count
        entity_bucket[:duration] += duration
        entity_bucket[:mapping_path] = metadata[:mapping_path] if metadata[:mapping_path]

        if metadata[:record_identifier]
          entity_bucket[:records] ||= []
          entity_bucket[:records] << metadata[:record_identifier]
        end

        @total_count += count
        @total_duration += duration
      end

      def result
        Result.new(operations: @operations, total_count: @total_count, total_duration: @total_duration)
      end
    end
  end
end
