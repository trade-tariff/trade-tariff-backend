module TariffKnowledge
  class NoteStructureValidator
    Result = Data.define(
      :source_type,
      :source_id,
      :source_version,
      :fragment_count,
      :event_count,
      :root_node_count,
      :total_node_count,
      :orphan_event_count,
      :orphan_event_keys,
      :duplicate_block_keys,
      :uncontained_fragment_keys,
      :issues,
    )
    Issue = Data.define(:severity, :code, :message, :details)
    Fragment = Data.define(:key, :content)

    def self.call(...) = new(...).call

    def initialize(
      source_type:,
      source_id:,
      source_version:,
      fragments: nil,
      content: nil,
      structure_parser: NoteStructureParser,
      block_parser: NoteBlockParser
    )
      @source_type = source_type.to_s
      @source_id = source_id.to_s
      @source_version = source_version.to_s
      @fragments = fragments
      @content = content
      @structure_parser = structure_parser
      @block_parser = block_parser
    end

    def call
      source_fragments = fragments || fragments_from_content
      tree = parse_tree(source_fragments)
      blocks = parse_blocks(source_fragments)
      issues = []

      orphan_event_keys = tree.orphans.map { |event| event.fragment.key }
      duplicate_block_keys = duplicate_keys(blocks.map(&:key))
      uncontained_fragment_keys = uncontained_fragment_keys(source_fragments, blocks, tree.events)

      issues << issue('warning', 'orphan_events', "#{orphan_event_keys.count} events could not attach to a note block", 'fragment_keys' => orphan_event_keys) if orphan_event_keys.any?
      issues << issue('error', 'duplicate_block_keys', "#{duplicate_block_keys.count} duplicate note block keys were emitted", 'block_keys' => duplicate_block_keys) if duplicate_block_keys.any?
      if uncontained_fragment_keys.any?
        issues << issue(
          'warning',
          'uncontained_fragments',
          "#{uncontained_fragment_keys.count} fragments were not contained by any emitted note block",
          'fragment_keys' => uncontained_fragment_keys,
        )
      end

      Result.new(
        source_type:,
        source_id:,
        source_version:,
        fragment_count: source_fragments.count,
        event_count: tree.events.count,
        root_node_count: tree.nodes.count,
        total_node_count: total_node_count(tree.nodes),
        orphan_event_count: orphan_event_keys.count,
        orphan_event_keys:,
        duplicate_block_keys:,
        uncontained_fragment_keys:,
        issues:,
      )
    end

  private

    attr_reader :source_type, :source_id, :source_version, :fragments, :content, :structure_parser, :block_parser

    def parse_tree(source_fragments)
      structure_parser.call(
        source_type:,
        source_id:,
        source_version:,
        fragments: source_fragments,
      )
    end

    def parse_blocks(source_fragments)
      block_parser.call(
        source_type:,
        source_id:,
        source_version:,
        fragments: source_fragments,
      )
    end

    def fragments_from_content
      split_content.map.with_index(1) do |fragment_content, index|
        Fragment.new(
          key: "note_fragment:#{source_type}:#{source_version}:#{source_id}:#{sprintf('%04d', index)}",
          content: fragment_content,
        )
      end
    end

    def split_content
      NoteFragmentSplitter.call(content)
    end

    def duplicate_keys(keys)
      keys.tally.select { |_, count| count > 1 }.keys
    end

    def uncontained_fragment_keys(_source_fragments, blocks, events)
      block_fragment_keys = blocks.flat_map(&:fragment_keys).uniq

      containable_event_keys(events)
        .excluding(*block_fragment_keys)
    end

    def containable_event_keys(events)
      events
        .select { |event| %i[alpha roman bullet].include?(event.kind) }
        .map { |event| event.fragment.key }
    end

    def total_node_count(nodes)
      nodes.sum { |node| 1 + total_node_count(node.children) }
    end

    def issue(severity, code, message, details)
      Issue.new(
        severity:,
        code:,
        message:,
        details:,
      )
    end
  end
end
