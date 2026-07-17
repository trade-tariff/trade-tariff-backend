require 'tariff_synchronizer/import/batch_record_inserter'

class CdsImporter
  class RecordInserter < TariffSynchronizer::Import::BatchRecordInserter
    SKIPPED_OPERATION = :skipped

  private

    def batch_size
      TradeTariffBackend.cds_importer_batch_size
    end

    def event_name
      'cds_importer.import.operations'
    end

    def grouped_records(records)
      records.group_by { |entity| entity.instance.class.operation_klass }.values
    end

    def event_payload(first_entity, group)
      {
        mapper: first_entity.mapper,
        operation: first_entity.instance.operation,
        count: group.size,
      }
    end

    def skipped_event_payload(entity)
      {
        mapper: entity.mapper,
        operation: SKIPPED_OPERATION,
        count: 1,
        record: entity.instance,
      }
    end

    def skip_records?
      true
    end

    def include_filename?
      true
    end

    def logger_enabled?
      CdsSynchronizer.cds_logger_enabled
    end
  end
end
