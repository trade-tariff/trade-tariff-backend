class TaricImporter
  class RecordProcessor
    class DestroyOperation < Operation
      def call
        # Build from the inbound TARIC attributes and write a destroy oplog entry.
        # Do not look up the current materialized projection first: same-file
        # create/destroy sequences are valid and the create is not visible until
        # views are refreshed after the full update file is applied.
        model = klass.new(attributes)
        model.destroy
        model
      end

      def to_oplog_operation
        :destroy
      end
    end
  end
end
