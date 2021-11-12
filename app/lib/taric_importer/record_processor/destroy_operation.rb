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
    end
  end
end
