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

        attr_accessor :entity_class,   # model
                      :entity_mapping, # attributes mapping
                      :mapping_path,   # path to attributes in xml
                      :mapping_root,   # node name in xml that provides data for mapping
                      :exclude_mapping # list of excluded attributes

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

        protected

        def before_oplog_inserts(&block)
          before_oplog_inserts_callbacks << block
        end

        def before_building_model(&block)
          before_building_model_callbacks << block
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
