require 'tariff_synchronizer/import/batch_record_inserter'

class TaricImporter
  class RecordInserter < TariffSynchronizer::Import::BatchRecordInserter
  private

    def batch_size
      TradeTariffBackend.taric_importer_batch_size
    end

    def event_name
      'taric_importer.import.operations'
    end

    def grouped_records(records)
      records.chunk_while do |left, right|
        left.instance.class.operation_klass ==
          right.instance.class.operation_klass &&
          left.instance.operation ==
            right.instance.operation
      end
    end

    def event_payload(first_entity, group)
      {
        mapper: first_entity.mapper,
        operation: first_entity.instance.operation,
        count: group.size,
      }
    end

    def default_operation_keys
      TaricImporter::OPERATION_KEYS
    end
  end
end
