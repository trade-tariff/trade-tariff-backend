class TaricImporter
  class RecordProcessor
    class Operation
      attr_reader :record

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
          'operation_date' => @operation_date
        )
      end

      def call
        raise NotImplementedError.new
      end

      def to_oplog_operation
        raise NotImplementedError.new
      end

      private

      def ignore_presence_errors?
        TariffSynchronizer.ignore_presence_errors
      end

      # Sometimes update operations go in wrong order (not chronologically, e.g. 'update' operation goes before 'create').
      # We decided to have ability to not break import process:
      #   set env TARIFF_IGNORE_PRESENCE_ERRORS=1 to ignore Sequel::RecordNotFound on update
      # We also decided to create new record if it does not exist
      def get_model_record
        filters = attributes.slice(*primary_key).symbolize_keys
        if ignore_presence_errors?
          model = klass.filter(filters).first
        else
          model = klass.filter(filters).take
        end
        model
      end

      def log_presence_error
        details = record.attributes.merge(
          transaction_id: record.transaction_id,
          operation_date: @operation_date,
          operation: to_oplog_operation
        )
        instrument('presence_error.taric_importer', klass: klass.to_s, details: details)
      end
    end
  end
end
