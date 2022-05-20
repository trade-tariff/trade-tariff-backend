Dir[Rails.root.join('app/lib/cds_importer/entity_mapper/*.rb')].sort.each { |f| require f }

class CdsImporter
  class EntityMapper
    delegate :instrument, to: ActiveSupport::Notifications
    delegate :applicable_mappers_for, to: :class

    attr_reader :xml_node, :key

    def initialize(key, xml_node)
      @key = key
      @xml_node = xml_node
      @filename = xml_node.delete('filename')
    end

    def import
      applicable_mappers_for(@key, @xml_node).each.with_object({}) do |mapper, oplog_inserts_performed|
        mapper.before_building_model_callbacks.each { |callback| callback.call(xml_node) }

        instances = mapper.parse

        mapper.before_oplog_inserts_callbacks.each { |callback| callback.call(xml_node, mapper) }

        instances.each do |i|
          oplog_inserts_performed[i.operation_klass.to_s] ||= 0

          oplog_oid = logger_enabled? ? save_record(i) : save_record!(i)

          oplog_inserts_performed[i.operation_klass.to_s] += 1 if oplog_oid
        end
      end
    end

    class << self
      # Constrains the applicable mappers in a primary node deletion operation
      #
      # This is required because CDS do not mark secondary and tertiary nested xml nodes for deletion
      # themselves and we have to ignore importing them in the event of the primary xml node being deleted as
      # this is managed by a separate callback process (see each primary entity mapper for what gets soft deleted).
      def applicable_mappers_for(key, xml_node)
        mappers = all_mappers.select { |mapper| mapper&.mapping_root == key }.sort_by(&:sort_key)
        mappers = mappers.map { |mapper| mapper.new(xml_node) }

        primary_mapper = mappers.first

        if primary_mapper&.destroy_operation?
          [primary_mapper]
        else
          mappers
        end
      end

      def all_mapping_roots
        all_mappers.map { |mapper| mapper&.mapping_root }.compact.sort.uniq
      end

      def all_mappers
        constants.map { |mapper| "CdsImporter::EntityMapper::#{mapper}".constantize }
      end
    end

    private

    def save_record!(record)
      values = record.values.except(:oid)

      values.merge!(filename: @filename)

      operation_klass = record.class.operation_klass

      if operation_klass.columns.include?(:created_at)
        values.merge!(created_at: operation_klass.dataset.current_datetime)
      end

      operation_klass.insert(values)
    end

    def save_record(record)
      save_record!(record)
    rescue StandardError => e
      instrument('cds_error.cds_importer', record:, xml_key: key, xml_node:, exception: e)
      nil
    end

    def instrument_warning(message, xml_node)
      instrument('apply.import_warnings', message:, xml_node:)
    end

    def logger_enabled?
      TariffSynchronizer.cds_logger_enabled
    end
  end
end
