class CdsImporter
  class RecordInserter
    SKIPPED_OPERATION = :skipped

    delegate :instrument, to: ActiveSupport::Notifications

    def initialize(record, mapper, filename)
      @record = record
      @mapper = mapper
      @filename = filename
    end

    def save_record!
      instrument('cds_importer.import.operations', mapper:, operation: record.operation, count: 1, record:) do
        operation_klass = record.class.operation_klass

        values = record.values.slice(*operation_klass.columns).except(:oid)

        values.merge!(filename:)

        if operation_klass.columns.include?(:created_at)
          values.merge!(created_at: operation_klass.dataset.current_datetime)
        end

        operation_klass.insert(values)
      end
    end

    def save_record(xml_key)
      save_record!
    rescue StandardError => e
      instrument('cds_error.cds_importer', record:, xml_key:, xml_node: mapper.xml_node, exception: e)
      nil
    end

    def instrument_skip_record
      instrument('cds_importer.import.operations', mapper:, operation: SKIPPED_OPERATION, count: 1, record:)
    end

    private

    attr_reader :record, :mapper, :filename
  end
end
