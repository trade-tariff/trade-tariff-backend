class CdsImporter
  class EntityMapper
    class BaseMapper
      class << self
        delegate :instrument, :subscribe, to: ActiveSupport::Notifications
        # entity_class    - model
        # entity_mapping  - attributes mapping
        # entity_mapping_key_as_array  - attributes mapping
        # mapping_path    - path to attributes in xml
        # mapping_root    - node name in xml that provides data for mapping
        # exclude_mapping - list of excluded attributes
        attr_accessor :entity_class, :entity_mapping, :mapping_path, :mapping_root, :exclude_mapping,
                      :entity_mapping_key_as_array, :entity_mapping_keys_to_parse

        def before_oplog_inserts_callbacks
          @before_oplog_inserts_callbacks ||= []
        end

        def base_mapping
          BASE_MAPPING.except(*exclude_mapping).keys.inject({}) do |memo, key|
            mapped_key = mapping_path.present? ? "#{mapping_path}.#{key}" : key
            memo[mapped_key] = BASE_MAPPING[key]
            memo
          end
        end

        def mapping_with_key_as_array
          entity_mapping.keys.inject({}) do |memo, key|
            memo[key.split(PATH_SEPARATOR)] = entity_mapping[key]
            memo
          end
        end

        def mapping_keys_to_parse
          mapping_with_key_as_array.keys.reject { |key|
            key.size == 1 ||
              key[0] == METAINFO
          }
        end

        def instrument_warning(message, xml_node)
          instrument('apply.import_warnings', message: message, xml_node: xml_node)
        end

        protected

        def before_oplog_inserts(&block)
          before_oplog_inserts_callbacks << block
        end
      end

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
        'metainfo.transactionDate' => :operation_date
      }.freeze

      def initialize(values)
        @values = values.slice(*entity_mapping_key_as_array.keys.map { |k| k[0] }.uniq)
      end

      # Sometimes we have array as a mapping path value,
      # so need to iterate through it and import each item separately
      def parse
        expanded = [@values]
        # iterating through all the mapping keys to expand Arrays
        entity_mapping_keys_to_parse.each do |path|
          current_path = []
          path.each do |key|
            current_path << key
            new_expanded = nil
            expanded.each do |values|
              value = values.dig(*current_path)
              if value.is_a?(Array)
                # iterating through all items in Array and creating @values copy
                value.each do |v|
                  # [1,2,3] => {1=>{2=>{3=>value}}
                  tmp = current_path.lazy.reverse_each.inject(v) { |memo, i| memo = { i => memo }; memo }
                  new_expanded ||= []
                  new_expanded << values.deep_merge(tmp)
                end
              end
            end
            expanded = new_expanded if new_expanded.present?
          end
        end
        # creating instances for all expanded values
        if mapping_path.present?
          expanded.select! { |values| values.dig(*mapping_path.split(PATH_SEPARATOR)).present? }
        end
        expanded.map { |values| create_instance(values) }
      end

      private

      def create_instance(values)
        normalized_values = normalized_values(mapped_values(values))
        instance = entity_class.constantize.new
        instance.set_fields(normalized_values, entity_mapping.values)
      end

      protected

      def entity_class
        self.class.entity_class.presence || raise(ArgumentError.new("entity_class has not been defined: #{self.class}"))
      end

      def mapping_path
        self.class.mapping_path.presence
      end

      def entity_mapping
        self.class.entity_mapping.presence || raise(ArgumentError.new("entity_mapping has not been defined: #{self.class}"))
      end

      def entity_mapping_key_as_array
        self.class.entity_mapping_key_as_array.presence || raise(ArgumentError.new("entity_mapping_key_as_array has not been defined: #{self.class}"))
      end

      def entity_mapping_keys_to_parse
        self.class.entity_mapping_keys_to_parse || raise(ArgumentError.new("entity_mapping_keys_to_parse has not been defined: #{self.class}"))
      end

      def mapped_values(values)
        entity_mapping_key_as_array.keys.inject({}) do |memo, key|
          mapped_key = entity_mapping_key_as_array[key]
          memo[mapped_key] = values.dig(*key)
          memo
        end
      end

      def normalized_values(values)
        values[:national] = (values[:national] == NATIONAL) if values.key?(:national)
        values[:approved_flag] = (values[:approved_flag] == APPROVED_FLAG) if values.key?(:approved_flag)
        values[:stopped_flag] = (values[:stopped_flag] == STOPPED_FLAG) if values.key?(:approved_flag)
        values
      end
    end
  end
end
