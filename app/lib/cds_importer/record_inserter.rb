class CdsImporter
  class RecordInserter
    SKIPPED_OPERATION = :skipped

    delegate :instrument, to: ActiveSupport::Notifications

    def initialize(record_batch, filename)
      @record_batch = record_batch
      @filename = filename
    end

    def save_batch
      record_batch.each do |entity|
        if entity.instance.skip_import?
          instrument_skip_record(entity.instance, entity.mapper)
        else
          instrument('cds_importer.import.operations', multi_insert: true, mapper: entity.mapper, operation: entity.instance.operation, count: 1, record: entity.instance)
        end
      end

      filtered_batch = record_batch.reject { |entity| entity.instance.skip_import? }
      grouped_batch = filtered_batch.group_by { |entity| entity.instance.class.operation_klass }

      grouped_batch.each do |operation_klass, group|
        save_group(operation_klass, group)
      rescue StandardError => e
        instrument('cds_error.cds_importer', multi_insert: true, type: operation_klass, exception: e)
        nil
      end
    end

    def save_group(operation_klass, group)
      value_batch = []
      group.each do |cds_entity|
        values = cds_entity.instance.values.slice(*operation_klass.columns).except(:oid)

        values[:filename] = filename

        if operation_klass.columns.include?(:created_at)
          values[:created_at] = operation_klass.dataset.current_datetime
        end
        value_batch << values
      end
      operation_klass.multi_insert(value_batch)
    end

    def instrument_skip_record(record, mapper)
      instrument('cds_importer.import.operations', mapper:, operation: SKIPPED_OPERATION, count: 1, record:)
    end

    private

    attr_reader :record_batch, :mapper, :filename

    def logger_enabled?
      CdsSynchronizer.cds_logger_enabled
    end
  end
end
