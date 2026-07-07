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

      # Temporary fix: the materialized-view lookup inherited from Operation can miss a
      # record created earlier in the same import file, since the view isn't refreshed
      # mid-import. Rather than querying the oplog table, build the instance straight from
      # this record's own attributes - #call immediately overwrites everything but the
      # primary key via model.set(...) anyway, so a lookup wouldn't keep anything extra.
      def get_model_record
        super || record_from_attributes
      rescue Sequel::RecordNotFound
        record_from_attributes || raise
      end

      def record_from_attributes
        return unless klass.materialized?

        klass.load(attributes.slice(*klass.columns.map(&:to_s)).symbolize_keys)
      end
    end
  end
end
