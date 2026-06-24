module TariffKnowledge
  class NoteBlockParser
    Block = Data.define(:key, :title, :content, :metadata, :fragment_keys)

    DEFINITION_MARKER = /\A(?<marker>[a-z]|ij)\.\s+(?<term>[[:alpha:]][[:alnum:][:space:]-]+)\z/i
    ROOT_MARKER = /\A(?<marker>\d+)\.\s+/
    BULLET_MARKER = /\A[-–—]\s+/
    HEADING_MARKER = /\A#+\s+(?<title>.+)\z/

    def self.call(...) = new(...).call

    def initialize(source_type:, source_id:, source_version:, fragments:)
      @source_type = source_type
      @source_id = source_id.to_s
      @source_version = source_version.to_s
      @fragments = fragments
    end

    def call
      blocks = []
      current_root = nil
      current_definition = nil
      current_section_slug = nil

      fragments.each do |fragment|
        text = fragment.content.to_s.squish
        heading_match = text.match(HEADING_MARKER)
        root_match = text.match(ROOT_MARKER)
        definition_match = text.match(DEFINITION_MARKER)

        if heading_match
          current_section_slug = heading_match[:title].parameterize(separator: '_')
          current_root = nil
          current_definition = nil
          next
        end

        if root_match
          current_root = root_match[:marker]
          current_definition = nil
        end

        if definition_match && current_root
          current_definition = new_definition_block(current_section_slug, current_root, definition_match, fragment)
          blocks << current_definition
          next
        end

        append_to_definition(current_definition, fragment) if current_definition && belongs_to_definition?(text)
      end

      blocks
    end

  private

    attr_reader :source_type, :source_id, :source_version, :fragments

    def new_definition_block(section_slug, root_marker, definition_match, fragment)
      term = definition_match[:term].squish
      marker = definition_match[:marker].downcase
      path = [section_slug, root_marker, marker].compact
      metadata = {
        'path' => path,
        'marker' => marker,
        'block_type' => 'definition',
        'term' => term.downcase,
      }
      metadata['section'] = section_slug if section_slug

      Block.new(
        key: "note_block:#{source_type}:#{source_version}:#{source_id}:#{path.join(':')}",
        title: term,
        content: fragment.content.to_s.squish,
        metadata:,
        fragment_keys: [fragment.key],
      )
    end

    def belongs_to_definition?(text)
      return true if text.match?(BULLET_MARKER)
      return false if text.match?(DEFINITION_MARKER)
      return false if text.match?(ROOT_MARKER)

      true
    end

    def append_to_definition(block, fragment)
      block.content << " #{fragment.content.to_s.squish}"
      block.fragment_keys << fragment.key
    end
  end
end
