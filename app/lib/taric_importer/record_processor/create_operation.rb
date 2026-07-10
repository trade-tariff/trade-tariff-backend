class TaricImporter
  class RecordProcessor
    class CreateOperation < Operation
      def call
        klass.new(attributes).save(validate: false, transaction: false)
      end

      def to_oplog_operation
        :create
      end
    end
  end
end
