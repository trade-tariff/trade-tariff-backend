class TaricImporter
  class RecordProcessor
    class Operation
      attr_reader :record, :operation_date

      delegate :klass, to: :record

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

    private

      # Hydrate from the inbound TARIC snapshot and append an oplog row.
      # Does not look up the current projection: same-file create then
      # update/destroy is valid and the create is not visible until views
      # refresh after the full update file is applied.
      def write_from_transaction
        model = klass.new(attributes)
        model.write_oplog_operation!(to_oplog_operation)
        model
      end
    end
  end
end
