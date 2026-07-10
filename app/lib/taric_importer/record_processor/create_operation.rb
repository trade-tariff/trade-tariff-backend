class TaricImporter
  class RecordProcessor
    class CreateOperation < Operation
      def call
        # Use Sequel save so the normal create path (_insert_raw) runs. In test,
        # that also refreshes materialized projections via _refresh_get; production
        # skips mid-file refreshes. Update/destroy use write_oplog_operation!
        # instead so they never depend on a live projection.
        klass.new(attributes).save(validate: false, transaction: false)
      end

      def to_oplog_operation
        :create
      end
    end
  end
end
