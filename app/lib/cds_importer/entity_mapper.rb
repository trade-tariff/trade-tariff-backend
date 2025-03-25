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
      cds_entities = []
      applicable_mappers_for(@key, @xml_node).each do |mapper|
        mapper.before_building_model_callbacks.each { |callback| callback.call(xml_node) }

        instances = mapper.parse

        instances.each do |model_configuration|
          model_instance = model_configuration[:instance]
          expanded_model_values = model_configuration[:expanded_attributes]

          mapper.before_oplog_inserts_callbacks.each do |callback|
            callback.call(
              xml_node,
              mapper,
              model_instance,
              expanded_model_values,
              implicit_deletes_enabled?,
            )
          end
          cds_entities << CdsImporter::CdsEntity.new(@key, model_instance, mapper)
        end
      end
      cds_entities
    end

    class << self
      def applicable_mappers_for(key, xml_node)
        mappers = all_mappers.select { |mapper| mapper&.mapping_root == key }.sort_by(&:sort_key)
        mappers.map { |mapper| mapper.new(xml_node) }
      end

      def all_mapping_roots
        all_mappers.map { |mapper| mapper&.mapping_root }.compact.sort.uniq
      end

      def all_mappers
        constants.map { |mapper| "CdsImporter::EntityMapper::#{mapper}".constantize }
      end
    end

    private

    def implicit_deletes_enabled?
      return file_date < TradeTariffBackend.implicit_deletion_cutoff if file_date

      false
    end

    def file_date
      return nil if @filename.blank?

      TariffSynchronizer::CdsUpdate.new(filename: @filename).file_date
    rescue StandardError
      nil
    end

    def instrument_warning(message, xml_node)
      instrument('apply.import_warnings', message:, xml_node:)
    end

    def logger_enabled?
      CdsSynchronizer.cds_logger_enabled
    end
  end
end
