class CdsImporter
  module XmlParser
    class Reader < Nokogiri::XML::SAX::Document
      EXTRA_CONTENT = /^\n\s+/
      CONTENT_KEY = :__content__

      def initialize(io_stream, target_handler)
        @io_stream = io_stream # Handle the IO stream (decompressed gzip content)
        @targets = CdsImporter::EntityMapper.all_mapping_roots
        @target_handler = target_handler
        @target_depth = 3
        @in_target = false
        @stack = []
        @depth = 0

        super()
      end

      # Stream parsing using the 'parse' method that accepts an IO-like object
      def parse_stream
        parser = Nokogiri::XML::SAX::Parser.new(self)

        # Parse the entire IO stream (gzipped XML) at once
        parser.parse(@io_stream) # Instead of feeding chunks, this will process the stream
      end

      def start_element(key, _attrs = [])
        if @depth == @target_depth && @targets.include?(key)
          @in_target = true
        end
        @depth += 1
        return unless @in_target

        @stack.last.delete(CONTENT_KEY) if @stack.any?
        @stack << @node = {}
        @node[CONTENT_KEY] = ''
      end

      def characters(val)
        # The XML we receive has a bunch of contiguous newline-starting strings that get passed to this callback
        # so we skip assigning any values that start with newline characters
        return if !@in_target || val =~ EXTRA_CONTENT

        # Ensure @node[CONTENT_KEY] is always initialized to an empty string before concatenating
        @node[CONTENT_KEY] ||= '' # Initialize if nil
        @node[CONTENT_KEY] += val if val # Append val to it
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
