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

      # Hydrate from the inbound TARIC snapshot and append an oplog row.
      # Does not look up the current projection: same-file create then
      # update/destroy is valid and the create is not visible until views
      # refresh after the full update file is applied.
      #
      # Omitted optional attributes are nil-filled by Record#default_attributes
      # (same as create). TARIC supplies the non-null snapshot fields for the
      # entity; it does not always list every DB column in the XML.
      def write_from_transaction
        ensure_primary_key_present!

        model = klass.new(attributes)
        model.write_oplog_operation!(to_oplog_operation)
        model
      end

      def ensure_primary_key_present!
        missing = Array(primary_key).select { |key| attributes[key].nil? }
        return if missing.empty?

        raise ArgumentError,
              "TARIC #{to_oplog_operation} for #{klass} missing primary key fields: #{missing.join(', ')}"
      end
    end
  end
end
