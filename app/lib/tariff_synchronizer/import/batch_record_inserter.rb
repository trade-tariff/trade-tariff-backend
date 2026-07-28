module TariffSynchronizer
  module Import
    class BatchRecordInserter
      delegate :instrument, to: ActiveSupport::Notifications

      def initialize(filename, staging_manager: nil)
        @record_batch = []
        @filename = filename
        @staging_manager = staging_manager
      end

      def process_record(entity)
        record_batch << entity
        process_batch if record_batch.size >= batch_size
      end

      def after_parse
        process_batch
      rescue StandardError => e
        "Taric import failed: #{e}".tap do |message|
          message << "\n Batch failed with ids:\n #{record_batch.map(&:element_id).join(', ')}"
          message << "\n Backtrace:\n #{e.backtrace.join("\n")}"
          Rails.logger.error message
        end
        raise e
      end

    private

      attr_reader :filename, :record_batch, :staging_manager

      def process_batch
        save_batch
        record_batch.clear
      end

      def save_batch
        instrument_skipped_records

        grouped_records(records_to_insert).each do |group|
          first_entity = group.first
          operation_klass = first_entity.instance.class.operation_klass

          instrument(event_name, event_payload(first_entity, group)) do
            save_group(operation_klass, group)
          end
        end
      end

      def save_group(operation_klass, group)
        value_batch = group.map do |entity|
          values_for(entity, operation_klass)
        end

        target_dataset(operation_klass).multi_insert(value_batch)
      end

      def values_for(entity, operation_klass)
        values = entity.instance.values.slice(*operation_klass.columns).except(:oid)
        values[:filename] = filename if include_filename?

        if operation_klass.columns.include?(:created_at)
          values[:created_at] = operation_klass.dataset.current_datetime
        end

        values
      end

      def target_dataset(operation_klass)
        if staging_manager
          staging_manager.dataset_for(operation_klass)
        else
          operation_klass
        end
      end

      def records_to_insert
        record_batch.reject { |entity| skip_record?(entity) }
      end

      def instrument_skipped_records
        record_batch.each do |entity|
          instrument(event_name, skipped_event_payload(entity)) if skip_record?(entity)
        end
      end

      def skip_record?(entity)
        skip_records? && entity.instance.skip_import?
      end

      def skip_records?
        false
      end

      def include_filename?
        false
      end

      def batch_size
        raise NotImplementedError
      end

      def event_name
        raise NotImplementedError
      end

      def event_payload(_first_entity, _group)
        raise NotImplementedError
      end

      def skipped_event_payload(_entity)
        raise NotImplementedError
      end

      def grouped_records(_records)
        raise NotImplementedError
      end
    end
  end
end
