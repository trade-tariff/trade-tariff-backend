#
# We are relying on CDS files structure, all target elements have depth == 3
#

class CdsImporter
  module XmlParser
    class Reader < ::Ox::Sax
      STRIP_NAMESPACE = '*'.freeze
      CONTENT_KEY = :__content__.freeze

      def initialize(stringio, target_handler)
        @stringio = stringio
        @targets = CdsImporter::EntityMapper::ALL_MAPPERS.map(&:mapping_root).compact.uniq
        @target_handler = target_handler
        @target_depth = 3
        @in_target = false
        @stack = []
        @depth = 0
      end

      def parse
        Ox.sax_parse self, @stringio, symbolize: false, strip_namespace: STRIP_NAMESPACE
      end

      def start_element(key)
        if @depth == @target_depth && @targets.include?(key)
          @in_target = true
        end
        @depth += 1
        return unless @in_target

        @stack << @node = {}
      end

      def text(val)
        return unless @in_target

        @node[:__content__] = val
      end

      def end_element(key)
        @depth -= 1
        if @depth == @target_depth && @targets.include?(key)
          @target_handler.process_xml_node(key, @stack[-1])
          @in_target = false
        end
        return unless @in_target

        child = @stack.pop
        @node = @stack.last

        case @node[key]
        when Array
          @node[key] << child
        when Hash
          @node[key] = [@node[key], child]
        else
          if child.size == 1 && child.key?(CONTENT_KEY)
            @node[key] = child[:__content__]
          else
            @node[key] = child
          end
        end
      end
    end
  end
end
