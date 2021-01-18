class TaricImporter
  module XmlParser
    class Reader < ::Ox::Sax
      def initialize(stringio, target, target_handler)
        @stringio = stringio
        @target = target
        @target_handler = target_handler
        @in_target = false
        @stack = []
      end

      def parse
        Ox.sax_parse self, @stringio, symbolize: false, strip_namespace: '*'
      end

      def start_element(key)
        @in_target = true if key == @target
        return unless @in_target

        @stack << @node = {}
      end

      def text(val)
        return unless @in_target

        @node[:__content__] = val
      end

      def end_element(key)
        if key == @target
          @target_handler.process_xml_node @stack[-1]
          @in_target = false
        end

        return unless @in_target

        child = @stack.pop
        @node = @stack.last

        key = replace_dots(key)

        case @node[key]
        when Array
          @node[key] << child
        when Hash
          @node[key] = [@node[key], child]
        else
          @node[key] = if child.keys == [:__content__]
                         child[:__content__]
                       else
                         child
                       end
        end
      end

    private

      def replace_dots(key)
        # Rails requires name attributes with underscore
        key.tr('.'.freeze, '_'.freeze)
      end
    end
  end
end
