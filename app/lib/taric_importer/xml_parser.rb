class TaricImporter
  module XmlParser
    class Reader < Nokogiri::XML::SAX::Document
      EXTRA_CONTENT = /\n\s+/
      CONTENT_KEY = :__content__

      def initialize(stringio, target, target_handler)
        @stringio = stringio
        @target = target
        @target_handler = target_handler
        @in_target = false
        @stack = []

        @stringio.rewind
        super()
      end

      def parse
        Nokogiri::XML::SAX::Parser.new(self).parse(@stringio)
      end

      def start_element(key, _attrs = [])
        key = strip_namespace(key)

        @in_target = true if key == @target
        return unless @in_target

        @stack << @node = {}
      end

      def characters(val)
        return if !@in_target || val =~ EXTRA_CONTENT

        @node[CONTENT_KEY] = val
      end

      def end_element(key)
        key = strip_namespace(key)

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
          @node[key] = if child.keys == [CONTENT_KEY]
                         child[CONTENT_KEY]
                       else
                         child
                       end
        end
      end

      def error(msg)
        raise(TaricImporter::ImportException, msg)
      end

    private

      def replace_dots(key)
        # Rails requires name attributes with underscore
        key.tr('.'.freeze, '_'.freeze)
      end

      def strip_namespace(key)
        key.match(/(?<namespace>\w+:)?(?<key>.+)/)[:key]
      end
    end
  end
end
