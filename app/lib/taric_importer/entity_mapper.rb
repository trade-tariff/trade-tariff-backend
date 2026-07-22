Dir[Rails.root.join('app/lib/taric_importer/entity_mapper/*.rb')].sort.each { |f| require f }

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

      klass = record_hash.keys.last.classify.constantize
      @mapper = self.class.mapper_for(klass).new(record_hash, klass)
    end

    def build
      validate_transaction!
      validate_primary_key!

      instance = mapper.klass.new(
        mapper.attributes(operation).merge(
          'operation' => operation,
          'operation_date' => issue_date,
        ),
      )

      entity = TaricEntity.new(element_id:, key: entity_key, instance:, mapper: self)

      yield entity if block_given?
      entity
    end

    def entity_class
      mapper.klass.to_s
    end

    class << self
      def mapper_for(klass)
        all_mappers.find { |mapper| mapper.entity_class == klass.to_s } || BaseMapper
      end

      # Unlike CDS's unfiltered `constants.map`, this filters to mapper classes only - EntityMapper
      # also has OPERATION_MAP as a top-level constant, which CDS's equivalent namespace doesn't.
      def all_mappers
        constants.map { |c| const_get(c) }.select { |k| k.is_a?(Class) && k < BaseMapper }
      end
    end

  private

    attr_reader :record_hash, :issue_date, :mapper

    def operation
      OPERATION_MAP.fetch(record_hash['update_type']) do
        Rails.logger.error "Unexpected Taric operation type: #{record_hash}"

        raise TaricImporter::UnknownOperationError,
              "Unknown TARIC operation: #{record_hash['update_type']}"
      end
    end

    def entity_key = record_hash.keys.last

    def element_id
      [record_hash['transaction_id'], record_hash['record_sequence_number']].join(':')
    end

    def validate_transaction!
      return if record_hash['transaction_id'].present?

      raise ArgumentError, 'TARIC transaction does not have required attributes'
    end

    def validate_primary_key!
      missing = mapper.primary_key.select { |key| mapper.attributes(operation)[key].blank? }

      return if missing.empty?

      raise ArgumentError,
            "TARIC #{operation} for #{mapper.klass} missing primary key: #{missing.join(', ')}"
    end
  end
end
