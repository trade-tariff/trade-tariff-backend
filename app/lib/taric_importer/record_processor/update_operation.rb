class TaricImporter
  class RecordProcessor
    class UpdateOperation < Operation
      def call
        model = get_model_record
        if model
          model.update(attributes.except(*primary_key).symbolize_keys)
        else
          log_presence_error
          model = TaricImporter::RecordProcessor::CreateOperation.new(record, @operation_date).call
        end
        model
      end

      def to_oplog_operation
        :update
      end
    end
  end
end
