class TaricImporter
  module XmlParser
    class Reader < Nokogiri::XML::SAX::Document
      EXTRA_CONTENT = /^\n\s+/
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
        @description = true if key == 'description'
        return unless @in_target

        @stack.last.delete(CONTENT_KEY) if @stack.any?
        @stack << @node = {}
        @node[CONTENT_KEY] = ''
      end

      def characters(val)
        # The XML we receive has a bunch of contiguous newline-starting strings that get passed to this callback so we
        # skip assigning any values that start with newline characters
        return if !@in_target || val =~ EXTRA_CONTENT

        @node[CONTENT_KEY] += val if val
      end

      def end_element(key)
        key = strip_namespace(key)

        if key == @target
          @target_handler.process_xml_node @stack.pop
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
