class CdsImporter
  module XmlParser
    class Reader < Nokogiri::XML::SAX::Document
      EXTRA_CONTENT = /^\n\s+/
      CONTENT_KEY = :__content__

      def initialize(stringio, target_handler)
        @stringio = stringio
        @targets = CdsImporter::EntityMapper.all_mapping_roots
        @target_handler = target_handler
        @target_depth = 3
        @in_target = false
        @stack = []
        @depth = 0

        super()
      end

      def parse
        Nokogiri::XML::SAX::Parser.new(self).parse(@stringio)
      end

      def start_element(key, _attrs = [])
        if @depth == @target_depth && @targets.include?(key)
          @in_target = true
        end
        @depth += 1
        return unless @in_target

        @stack << @node = {}
      end

      def characters(val)
        # The XML we receive has a bunch of contiguous newline-starting strings that get passed to this callback so we
        # skip assigning any values that start with newline characters
        return if !@in_target || val =~ EXTRA_CONTENT

        @node[CONTENT_KEY] = val
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
          @node[key] = if child.size == 1 && child.key?(CONTENT_KEY)
                         child[CONTENT_KEY]
                       else
                         child
                       end
        end
      end

      def error(msg)
        raise(CdsImporter::ImportException, msg)
      end
    end
  end
end
