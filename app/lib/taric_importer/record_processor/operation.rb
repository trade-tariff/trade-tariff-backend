class TaricImporter
  class RecordProcessor
    class Operation
      attr_reader :record, :operation_date

      delegate :klass, :primary_key, to: :record

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

      def write_from_transaction
        ensure_primary_key_present!

        model = klass.new(attributes)
        model.write_oplog_operation!(to_oplog_operation)
        model
      end

      def ensure_primary_key_present!
        missing = Array(primary_key).select { |key| attributes[key].blank? }
        return if missing.empty?

        raise ArgumentError,
              "TARIC #{to_oplog_operation} for #{klass} missing primary key fields: #{missing.join(', ')}"
      end
    end
  end
end
