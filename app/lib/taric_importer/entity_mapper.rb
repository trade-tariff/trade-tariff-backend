class TaricImporter
  class EntityMapper
    OPERATION_MAP = {
      '1' => :update,
      '2' => :destroy,
      '3' => :create,
    }.freeze

    def initialize(record_hash, issue_date:)
      @record_hash = record_hash
      @issue_date = issue_date
      @record = RecordProcessor::Record.new(record_hash)
    end

    def build
      validate_transaction!
      validate_primary_key!

      instance = record.klass.new(
        record.attributes.merge(
          'operation' => operation,
          'operation_date' => issue_date,
        ),
      )

      entity = TaricEntity.new(
        element_id: element_id,
        key: entity_key,
        instance:,
        mapper: self,
      )

      yield entity if block_given?
      entity
    end

    def entity_class
      record.klass.to_s
    end

    def mapping_path
      nil
    end

  private

    attr_reader :record_hash, :issue_date, :record

    def operation
      OPERATION_MAP.fetch(record_hash['update_type']) do
        Rails.logger.error "Unexpected Taric operation type: #{record}"

        raise TaricImporter::UnknownOperationError,
              "Unknown TARIC operation: #{record_hash['update_type']}"
      end
    end

    def entity_key
      record_hash.keys.last
    end

    def element_id
      [
        record_hash['transaction_id'],
        record_hash['record_sequence_number'],
      ].join(':')
    end

    def validate_transaction!
      return if record_hash['transaction_id'].present?

      raise ArgumentError,
            'TARIC transaction does not have required attributes'
    end

    def validate_primary_key!
      missing = record.primary_key.select do |key|
        record.attributes[key].blank?
      end

      return if missing.empty?

      raise ArgumentError,
            "TARIC #{operation} for #{record.klass} missing primary key: #{missing.join(', ')}"
    end
  end
end
