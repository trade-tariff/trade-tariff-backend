class TaricImporter
  class RecordProcessor
    class Operation
      attr_reader :record, :operation_date

      delegate :primary_key, :klass, to: :record
      delegate :instrument, to: ActiveSupport::Notifications

      def initialize(record, operation_date)
        @record = record
        @operation_date = operation_date
      end

      # Taric operation adds date and operation type
      # for Oplog
      def attributes
        record.attributes.merge(
          'operation' => to_oplog_operation,
          'operation_date' => operation_date,
        )
      end

      def call
        raise NotImplementedError
      end

      def to_oplog_operation
        raise NotImplementedError
      end
    end
  end
end
