class CdsImporter
  class EntityMapper
    class BaseMapper
      NATIONAL = 'N'.freeze
      APPROVED_FLAG = '1'.freeze
      STOPPED_FLAG = '1'.freeze
      PATH_SEPARATOR = '.'.freeze
      METAINFO = 'metainfo'.freeze
      BASE_MAPPING = {
        'validityStartDate' => :validity_start_date,
        'validityEndDate' => :validity_end_date,
        'metainfo.origin' => :national,
        'metainfo.opType' => :operation,
        'metainfo.transactionDate' => :operation_date,
      }.freeze

      delegate :entity_class,
               :entity_mapping,
               :mapping_path,
               :mapping_root,
               :exclude_mapping,
               :mapping_with_key_as_array,
               :mapping_keys_to_parse,
               :before_oplog_inserts_callbacks,
               :before_building_model_callbacks,
               :name,
               to: :class

      class << self
        delegate :instrument, :subscribe, to: ActiveSupport::Notifications

        attr_accessor :entity_class,        # model
                      :entity_mapping,      # attributes mapping
                      :mapping_path,        # path to attributes in xml
                      :mapping_root,        # node name in xml that provides data for mapping
                      :exclude_mapping,     # list of excluded attributes
                      :primary_key_mapping, # how we pull out the (often composite) primary key from the xml node document
                      :primary_filters      # how we know what secondaries are associated with the primary

        def before_oplog_inserts_callbacks
          @before_oplog_inserts_callbacks ||= []
        end

        def before_building_model_callbacks
          @before_building_model_callbacks ||= []
        end

        def base_mapping
          BASE_MAPPING.except(*exclude_mapping).keys.each_with_object({}) do |key, memo|
            mapped_key = mapping_path.present? ? "#{mapping_path}.#{key}" : key
            memo[mapped_key] = BASE_MAPPING[key]
          end
        end

        # Register a callback to soft delete missing entities based on the passed in configuration
        #
        # Each secondary entity can have the following configuration:
        #   filter: The filter used to find the secondary entities for soft deletion
        #   relation_mapping_path: How we dig through the xml node to determine the secondaries that are being imported
        #   relation_primary_key: How we understand the mapping between the model's primary key and the xml nodes primary key
        def delete_missing_entities(*secondary_mappers)
          before_oplog_inserts do |xml_node, _mapper_instance, model_instance|
            if TradeTariffBackend.handle_soft_deletes?
              secondary_mappers.each do |secondary_mapper|
                database_entities = database_entities_for(model_instance, secondary_mapper)
                xml_node_entities = xml_entities_for(xml_node, secondary_mapper)
                missing_entities = database_entities - xml_node_entities
                missing_entity_filter = secondary_mapper.missing_entity_filter_for(missing_entities)

                secondary_mapper.entity.where(missing_entity_filter).destroy
              end
            end
          end
        end

        def entity
          entity_class.constantize
        end

        def mapping_with_key_as_array
          @mapping_with_key_as_array ||= entity_mapping.keys.each_with_object({}) do |key, memo|
            memo[key.split(PATH_SEPARATOR)] = entity_mapping[key]
          end
        end

        def mapping_keys_to_parse
          @mapping_keys_to_parse ||= mapping_with_key_as_array.keys.reject do |key|
            key.size == 1 ||
              key[0] == METAINFO
          end
        end

        def instrument_warning(message, xml_node)
          instrument('apply.import_warnings', message:, xml_node:)
        end

        def sort_key
          "#{mapping_path.to_s.length}#{name}"
        end

        # Returns sequel filter args that will find all secondaries associated with a primary model instance
        def filter_for(primary_model_instance)
          primary_filters.each_with_object({}) do |(primary_field, secondary_field), acc|
            acc[secondary_field] = primary_model_instance.public_send(primary_field)
          end
        end

        # Returns sequel filter args that will find all missing secondaries based on the primary key index order
        # defined by the underlying secondary entity model class
        def missing_entity_filter_for(missing_entities)
          entity_composite_primary_key.each_with_object({}).with_index do |(primary_key_field, acc), index|
            acc[primary_key_field] = missing_entities.map { |entity| entity[index] }
          end
        end

        def relative_primary_key_paths_for_secondary_node
          primary_key_paths_for_secondary_node.each_with_object({}) do |path, acc|
            relative_path = path.sub("#{mapping_path}.", '')

            acc[relative_path] = primary_key_mapping[path]
          end
        end

        def primary_key_paths_for_primary_node
          primary_node_paths = primary_key_mapping.keys - primary_key_paths_for_secondary_node

          primary_node_paths.index_with { |path| primary_key_mapping[path] }
        end

        def primary_key_paths_for_secondary_node
          primary_key_mapping.keys.grep(/#{mapping_path}/)
        end

        def entity_composite_primary_key
          Array.wrap(entity.primary_key)
        end

        protected

        def before_oplog_inserts(&block)
          before_oplog_inserts_callbacks << block
        end

        def before_building_model(&block)
          before_building_model_callbacks << block
        end

        private

        def xml_entities_for(xml_node, secondary_mapper)
          xml_node_entities = Array.wrap(xml_node.fetch(secondary_mapper.mapping_path, []))

          xml_node_entities.map do |xml_entity|
            composite_primary_key = {}

            accumulate_primary_key_parts_for( secondary_mapper.relative_primary_key_paths_for_primary_node, xml_node, composite_primary_key,)

            accumulate_primary_key_parts_for( secondary_mapper.relative_primary_key_paths_for_secondary_node, xml_entity, composite_primary_key,)

            secondary_mapper.entity_composite_primary_key.map do |model_primary_key_part|
              composite_primary_key[model_primary_key_part]
            end
          end
        end

        def accumulate_primary_key_parts_for(paths, xml_node, composite_primary_key)
          paths.each do |xml_path, model_primary_key_part|
            primary_key_part = xml_node.dig(*xml_path.split('.'))

            composite_primary_key[model_primary_key_part] = primary_key_part
          end
        end

        def database_entities_for(primary_model_instance, secondary_mapper)
          filter = secondary_mapper.filter_for(primary_model_instance)
          primary_keys = secondary_mapper.entity.primary_key

          secondary_mapper.entity.where(filter).pluck(*primary_keys).map do |composite_primary_key|
            composite_primary_key.map(&:to_s)
          end
        end
      end

      def initialize(xml_node)
        @xml_node = xml_node
      end

      # Sometimes we have array as a mapping path value,
      # so need to iterate through it and import each item separately
      def parse
        expanded = [@xml_node]
        # iterating through all the mapping keys to expand Arrays
        mapping_keys_to_parse.each do |path|
          current_path = []
          path.each do |key|
            current_path << key
            new_expanded = nil
            expanded.each do |values|
              value = values.dig(*current_path)
              next unless value.is_a?(Array)

              # iterating through all items in Array and creating @values copy
              value.each do |v|
                # [1,2,3] => {1=>{2=>{3=>value}}
                tmp = current_path.lazy.reverse_each.inject(v) do |memo, i|
                  memo = { i => memo }
                  memo
                end
                new_expanded ||= []
                new_expanded << values.deep_merge(tmp)
              end
            end
            expanded = new_expanded if new_expanded.present?
          end
        end
        # creating instances for all expanded values
        if mapping_path.present?
          expanded.select! { |values| values.dig(*mapping_path.split(PATH_SEPARATOR)).present? }
        end
        expanded.map(&method(:build_instance))
      end

      def destroy_operation?
        @xml_node.dig('metainfo', 'opType') == Sequel::Plugins::Oplog::DESTROY_OPERATION &&
          primary? &&
          TradeTariffBackend.handle_soft_deletes?
      end

      private

      def build_instance(values)
        values = mapped_values(values)
        normalized_values = normalized_values(values)
        instance = entity_class.constantize.new
        instance.set_fields(normalized_values, entity_mapping.values)
      end

      def mapped_values(values)
        mapping_with_key_as_array.keys.each_with_object({}) do |key, memo|
          mapped_key = mapping_with_key_as_array[key]
          memo[mapped_key] = values.dig(*key)
        end
      end

      def normalized_values(values)
        values[:national] = (values[:national] == NATIONAL) if values.key?(:national)
        values[:approved_flag] = (values[:approved_flag] == APPROVED_FLAG) if values.key?(:approved_flag)
        values[:stopped_flag] = (values[:stopped_flag] == STOPPED_FLAG) if values.key?(:approved_flag)
        values
      end

      # In the CDS file we treat the parent node differently from the
      # secondary child nodes when it comes to support for the destroy operation.
      #
      # Each entity mapper represents either a child or a parent node in the xml file.
      #
      # Parent nodes have the same assigned entity class as their derived class. Our internal naming
      # for this has been to name this parent node the primary.
      def primary?
        derived_entity_class == entity_class
      end

      def derived_entity_class
        name.match(/\ACdsImporter::EntityMapper::(?<entity_class>.*)Mapper\z/).try(:[], :entity_class)
      end
    end
  end
end
