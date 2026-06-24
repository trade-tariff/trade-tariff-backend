module TariffKnowledge
  class NoteStructureParser
    Tree = Data.define(:nodes, :events, :orphans)
    Node = Data.define(:kind, :marker, :path, :title, :content, :fragment_keys, :children)

    BLOCK_CANDIDATE_KINDS = %i[alpha roman].freeze

    def self.call(...) = new(...).call

    def initialize(source_type:, source_id:, source_version:, fragments:, classifier: NoteMarkerClassifier)
      @source_type = source_type
      @source_id = source_id.to_s
      @source_version = source_version.to_s
      @fragments = fragments
      @classifier = classifier
      @events = []
      @orphans = []
      @root_nodes = []
      @path_segments = {}
      @active_blocks = {}
    end

    def call
      fragments.each do |fragment|
        event = classifier.call(fragment)
        events << event

        process(event)
      end

      Tree.new(
        nodes: root_nodes.map(&:to_node),
        events:,
        orphans:,
      )
    end

  private

    attr_reader :classifier, :events, :fragments, :orphans, :root_nodes, :path_segments, :active_blocks

    def process(event)
      case event.kind
      when :heading
        reset_context
        path_segments[event.depth] = event.path_segment
      when :numeric
        reset_at_depth(event.depth)
        path_segments[event.depth] = event.path_segment
      when *BLOCK_CANDIDATE_KINDS
        add_block_candidate(event)
      when :bullet, :continuation
        append_to_active_block(event)
      end
    end

    def add_block_candidate(event)
      reset_at_depth(event.depth)
      path_segments[event.depth] = event.path_segment

      block = MutableNode.new(event, path)
      parent = nearest_active_block(event.depth - 1)

      if parent
        parent.children.push(block)
      else
        root_nodes << block
      end

      active_blocks[event.depth] = block
    end

    def append_to_active_block(event)
      block = nearest_active_block

      if block
        block.append(event)
      else
        orphans << event
      end
    end

    def reset_context
      path_segments.clear
      active_blocks.clear
    end

    def reset_at_depth(depth)
      path_segments.delete_if { |segment_depth, _| segment_depth >= depth }
      active_blocks.delete_if { |block_depth, _| block_depth >= depth }
    end

    def path
      path_segments.sort_by { |depth, _| depth }.map(&:last)
    end

    def nearest_active_block(max_depth = nil)
      active_blocks
        .select { |depth, _| max_depth.nil? || depth <= max_depth }
        .max_by { |depth, _| depth }
        &.last
    end

    class MutableNode
      attr_reader :kind, :marker, :path, :title, :children

      def initialize(event, path)
        @kind = event.kind
        @marker = event.marker
        @path = path
        @title = event.title || event.body.presence
        @content_parts = [event.raw_text]
        @fragment_keys = [event.fragment.key]
        @children = []
      end

      def append(event)
        content_parts << event.raw_text
        fragment_keys << event.fragment.key
      end

      def to_node
        Node.new(
          kind:,
          marker:,
          path: path.dup.freeze,
          title:,
          content: content_parts.join(' ').squish,
          fragment_keys: fragment_keys.dup.freeze,
          children: children.map(&:to_node).freeze,
        )
      end

    private

      attr_reader :content_parts, :fragment_keys
    end
  end
end
