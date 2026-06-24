module TariffKnowledge
  class NoteFragmentSplitter
    LIST_MARKER_PATTERN = /\A(?:ij|\(?[a-z]\)?|[ivx]+|\d+)\.\z/i
    TRAILING_LIST_MARKER_PATTERN = /\A(.+?)\s+((?:ij|\(?[a-z]\)?|[ivx]+|\d+)\.)\z/im

    def self.call(...) = new(...).call

    def initialize(content)
      @content = content
    end

    def call
      content
        .to_s
        .split(/\n{2,}|(?<=[.!?])\s+/)
        .map(&:strip)
        .reject(&:blank?)
        .then { |split_fragments| merge_orphaned_list_markers(split_fragments) }
        .then { |split_fragments| merge_dangling_numeric_references(split_fragments) }
    end

  private

    attr_reader :content

    def merge_orphaned_list_markers(split_fragments)
      split_fragments.each_with_object([]) do |fragment, merged|
        fragment = "#{merged.pop} #{fragment}" if list_marker_sequence?(merged.last)
        match = fragment.match(TRAILING_LIST_MARKER_PATTERN)
        text, marker = match&.captures

        if match && !list_marker_sequence?(text.strip)
          merged.push(text.strip, marker)
        else
          merged << (match ? "#{text.strip} #{marker}" : fragment)
        end
      end
    end

    def list_marker_sequence?(fragment)
      fragment.present? && fragment.split.all? { |part| part.match?(LIST_MARKER_PATTERN) }
    end

    def merge_dangling_numeric_references(split_fragments)
      split_fragments.each_with_object([]) do |fragment, merged|
        if merged.last && dangling_numeric_reference?(merged.last, fragment)
          attach_reference_fragment(fragment, merged)
        else
          merged << fragment
        end
      end
    end

    def dangling_numeric_reference?(previous_fragment, fragment)
      numeric_reference_context?(previous_fragment, fragment) ||
        (fragment.match?(/\AC\.(?:\s+.+)?\z/i) && previous_fragment.match?(/\d\z/))
    end

    def attach_reference_fragment(fragment, merged)
      reference, remaining_fragment = fragment.match(/\A((?:\d{1,4}|C)\.)\s*(.*)\z/i).captures
      merged[-1] = "#{merged.last} #{reference}"
      merged << remaining_fragment.strip if remaining_fragment.present?
    end

    def numeric_reference_context?(previous_fragment, fragment)
      fragment.match?(/\A\d{1,4}\.(?:\s+.+)?\z/) &&
        (
          previous_fragment.match?(/\b(?:heading|headings|chapter|chapters|rule|rules|and|or|to)\z/i) ||
            previous_fragment.match?(/\d\z/) ||
            fragment.match?(/\A(?:19|20)\d{2}\.(?:\s+.+)?\z/)
        )
    end
  end
end
