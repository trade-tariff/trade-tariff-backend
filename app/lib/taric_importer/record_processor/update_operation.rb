class TaricImporter
  class RecordProcessor
    class UpdateOperation < Operation
      def call
        # Write the update from the inbound TARIC attributes without requiring a
        # row in the current materialized projection. TARIC update records carry
        # a full attribute set for the logical entity.
        model = klass.new(attributes)
        model.send(:_update_columns, nil)
        model
      end

      def to_oplog_operation
        :update
      end
    end
  end
end
