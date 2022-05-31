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
      applicable_mappers_for(@key, @xml_node).each do |mapper|
        mapper.before_building_model_callbacks.each { |callback| callback.call(xml_node) }

        instances = mapper.parse

        instances.each do |model_instance|
          mapper.before_oplog_inserts_callbacks.each { |callback| callback.call(xml_node, mapper, model_instance) }
          record_inserter = CdsImporter::RecordInserter.new(model_instance, mapper, @filename)

          if logger_enabled?
            record_inserter.save_record(@key)
          else
            record_inserter.save_record!
          end
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

        primary_mapper = mappers.find(&:primary?)

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

    def instrument_warning(message, xml_node)
      instrument('apply.import_warnings', message:, xml_node:)
    end

    def logger_enabled?
      TariffSynchronizer.cds_logger_enabled
    end
  end
end
