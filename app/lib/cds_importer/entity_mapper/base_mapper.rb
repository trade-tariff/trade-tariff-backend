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

        def inherited(subclass)
          if TradeTariffBackend.dump_cds_data_as_json?
            subclass.before_oplog_inserts do |_xml_node, _mapper_instance, model_instance, _expanded_attributes|
              id = model_instance.identification.values.join('-')
              filename = "data/cds_dumps/#{model_instance.class.table_name}-#{id}-#{Time.zone.today.iso8601}.json"

              File.write(filename, JSON.pretty_generate(model_instance.values))
            end
          end

          super
        end

        def base_mapping
          BASE_MAPPING.except(*exclude_mapping).keys.each_with_object({}) do |key, memo|
            mapped_key = mapping_path.present? ? "#{mapping_path}.#{key}" : key
            memo[mapped_key] = BASE_MAPPING[key]
          end
        end

        # Register a callback to soft delete missing entities indicated by the passed in secondary mappers
        def delete_missing_entities(*secondary_mappers)
          before_oplog_inserts do |xml_node, mapper_instance, primary_model_instance, _expanded_attributes|
            if TradeTariffBackend.handle_missing_soft_deletes?
              secondary_mappers.each do |secondary_mapper|
                database_entities = secondary_mapper.database_entities_for(primary_model_instance)
                xml_node_entities = secondary_mapper.xml_entities_for(xml_node)
                missing_entities = database_entities - xml_node_entities
                missing_entity_filter = secondary_mapper.missing_entity_filter_for(missing_entities)

                secondary_mapper.entity.where(missing_entity_filter).each do |missing_entity|
                  inserter = CdsImporter::RecordInserter.new(missing_entity, secondary_mapper, mapper_instance.filename)

                  inserter.destroy_missing_record
                end
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

        def entity_composite_primary_key
          Array.wrap(entity.primary_key)
        end

        def database_entities_for(primary_model_instance)
          filter = filter_for(primary_model_instance)

          entity.where(filter).pluck(*entity.primary_key).map do |composite_primary_key|
            Array.wrap(composite_primary_key)
          end
        end

        def xml_entities_for(xml_node)
          xml_node_entities = new(xml_node).parse.map { |model_configuration| model_configuration[:instance] }

          xml_node_entities.pluck(*entity.primary_key).map(&Array.method(:wrap))
        end

        protected

        def before_oplog_inserts(&block)
          before_oplog_inserts_callbacks << block
        end

        def before_building_model(&block)
          before_building_model_callbacks << block
        end
      end

      attr_reader :xml_node

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
                tmp = current_path.reverse.inject(v) do |memo, i|
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
        # building instances for all expanded values
        if mapping_path.present?
          expanded.select! { |values| values.dig(*mapping_path.split(PATH_SEPARATOR)).present? }
        end
        expanded.map(&method(:build_instance))
      end

      def filename
        @xml_node['filename']
      end

      private

      def build_instance(values)
        unmapped_values = values
        values = mapped_values(values)
        normalized_values = normalized_values(values)
        instance = entity_class.constantize.new
        { instance: instance.set_fields(normalized_values, entity_mapping.values), expanded_attributes: unmapped_values }
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

      def derived_entity_class
        name.match(/\ACdsImporter::EntityMapper::(?<entity_class>.*)Mapper\z/).try(:[], :entity_class)
      end
    end
  end
end
