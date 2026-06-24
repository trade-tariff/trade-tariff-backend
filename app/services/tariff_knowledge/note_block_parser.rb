module TariffKnowledge
  class NoteBlockParser
    Block = Data.define(:key, :title, :content, :metadata, :fragment_keys)

    def self.call(...) = new(...).call

    def initialize(source_type:, source_id:, source_version:, fragments:, structure_parser: NoteStructureParser)
      @source_type = source_type
      @source_id = source_id.to_s
      @source_version = source_version.to_s
      @fragments = fragments
      @structure_parser = structure_parser
    end

    def call
      tree = structure_parser.call(
        source_type:,
        source_id:,
        source_version:,
        fragments:,
      )

      flatten_nodes(tree.nodes).filter_map { |node| block_for(node) }
    end

  private

    attr_reader :source_type, :source_id, :source_version, :fragments, :structure_parser

    def flatten_nodes(nodes)
      nodes.flat_map { |node| [node, *flatten_nodes(node.children)] }
    end

    def block_for(node)
      path = node.path.map(&:to_s)
      return unless definition_path?(path)

      marker = node.marker.to_s
      term = node.title.to_s.squish
      return if term.blank?

      fragment_keys = descendant_fragment_keys(node)
      metadata = {
        'path' => path,
        'marker' => marker,
        'block_type' => 'definition',
        'term' => term.downcase,
        'marker_kind' => node.kind.to_s,
      }
      metadata['section'] = section_slug(path) if section_slug(path)

      Block.new(
        key: "note_block:#{source_type}:#{source_version}:#{source_id}:#{path.join(':')}",
        title: term,
        content: descendant_content(node),
        metadata:,
        fragment_keys:,
      )
    end

    def section_slug(path)
      path.first unless path.first.to_s.match?(/\A\d+\z/)
    end

    def definition_path?(path)
      path.any? { |segment| segment.match?(/\A\d+\z/) }
    end

    def descendant_content(node)
      [node.content, *node.children.map { |child| descendant_content(child) }].join(' ').squish
    end

    def descendant_fragment_keys(node)
      [node.fragment_keys, *node.children.map { |child| descendant_fragment_keys(child) }].flatten
    end
  end
end
