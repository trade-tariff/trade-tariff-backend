class TaricImporter
  class RecordProcessor
    class DestroyOperation < Operation
      def call
        write_from_transaction
      end

      def to_oplog_operation
        :destroy
      end
    end
  end
end
