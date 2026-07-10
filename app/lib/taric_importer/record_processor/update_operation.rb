class TaricImporter
  class RecordProcessor
    class UpdateOperation < Operation
      def call
        write_from_transaction
      end

      def to_oplog_operation
        :update
      end
    end
  end
end
