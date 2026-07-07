class TaricImporter
  class RecordProcessor
    class DestroyOperation < Operation
      def call
        model = get_model_record
        if model
          model.set(attributes.except(*primary_key).symbolize_keys)
          model.destroy
        else
          log_presence_error
        end
        model
      end

      def to_oplog_operation
        :destroy
      end

      private

      # Falls back to the live oplog table when the materialized view (queried by
      # the inherited lookup) hasn't caught up yet with a record created earlier
      # in the same import run.
      def get_model_record
        super || record_from_latest_oplog_entry
      rescue Sequel::RecordNotFound
        record_from_latest_oplog_entry || raise
      end

      def record_from_latest_oplog_entry
        return unless klass.materialized?

        filters = attributes.slice(*primary_key).symbolize_keys
        latest = klass.operation_klass.where(filters).order(Sequel.desc(:oid)).first
        return if latest.nil? || latest[:operation] == Sequel::Plugins::Oplog::DESTROY_OPERATION

        klass.load(latest.values.slice(*klass.columns))
      end
    end
  end
end
