class CdsImporter
  class RecordInserter
    class << self
      delegate :instrument, :subscribe, to: ActiveSupport::Notifications

      def destroy_cascade_record(record, mapper, filename)
        instrument('cds_importer.import.operations', mapper:, operation: :destroy_cascade, count: 1) do
          operation_klass = record.class.operation_klass

          values = record.values.except(:oid)
          values[:filename] = filename
          values[:operation] = Sequel::Plugins::Oplog::DESTROY_OPERATION
          values[:created_at] = operation_klass.dataset.current_datetime if operation_klass.columns.include?(:created_at)

          operation_klass.insert(values)
        end
      end

      def destroy_missing_record(record, mapper, filename)
        instrument('cds_importer.import.operations', mapper:, operation: :destroy_missing, count: 1) do
          operation_klass = record.class.operation_klass

          values = record.values.except(:oid)
          values[:filename] = filename
          values[:operation] = Sequel::Plugins::Oplog::DESTROY_OPERATION
          values[:created_at] = operation_klass.dataset.current_datetime if operation_klass.columns.include?(:created_at)

          operation_klass.insert(values)
        end
      end

      def save_record!(record, mapper, filename)
        instrument('cds_importer.import.operations', mapper:, operation: record.operation, count: 1) do
          values = record.values.except(:oid)

          values.merge!(filename:)

          operation_klass = record.class.operation_klass

          if operation_klass.columns.include?(:created_at)
            values.merge!(created_at: operation_klass.dataset.current_datetime)
          end

          operation_klass.insert(values)
        end
      end

      def save_record(record, mapper, filename, xml_key)
        save_record!(record, mapper, filename)
      rescue StandardError => e
        instrument('cds_error.cds_importer', record:, xml_key:, xml_node: mapper.xml_node, exception: e)
        nil
      end
    end
  end
end
