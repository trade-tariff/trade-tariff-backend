module CustomsTariffImporter
  class NotesExtractor
    class Formatter
      class MarkerTrie
        ROMAN_MARKER_PATTERN = /(?:i{1,3}|iv|v|vi{0,3}|ix)/i
        ALPHABETIC_DOTTED_MARKER_PATTERN = /(?:[a-z]|ij)\./i
        MARKER_TEXT_PATTERN = /\A(?:#{ALPHABETIC_DOTTED_MARKER_PATTERN}|\([A-Z]\)|\([ivxlcdm]+\)|[ivxlcdm]+\.|\(\d+\)|\d+\.)\s+\S/i
        ALPHABETIC_MARKER_TEXT_PATTERN = /\A#{ALPHABETIC_DOTTED_MARKER_PATTERN}\s+\S/i
        ROMAN_MARKER_TEXT_PATTERN = /\A#{ROMAN_MARKER_PATTERN}\.\s+\S/
        SOURCE_MARKER_LINE_PATTERN = /\A\s+(?:-\s+)?(?:#{ALPHABETIC_DOTTED_MARKER_PATTERN}|\([A-Z]\)|\([ivxlcdm]+\)|[ivxlcdm]+\.|\(\d+\)|\d+\.)\s+\S/i
        MARKER_LINE_PATTERN = /\A(?<spaces> *)(?:-\s+)?(?<marker>\(\d+\)|\d+\.|ij\.|#{ROMAN_MARKER_PATTERN}\.|[a-z]\.|\([a-z]+\))\s+\S/i
        SOURCE_PARENT_MARKER_LINE_PATTERN = /\A\s+(?:-\s+)?(?:#{ALPHABETIC_DOTTED_MARKER_PATTERN}|\((?![ivx]+\))[a-z]\))\s+\S/i
        SOURCE_CHILD_MARKER_LINE_PATTERN = /\A\s+(?:-\s+)?(?:\(\d+\)|\d+\.|#{ROMAN_MARKER_PATTERN}\.|\(#{ROMAN_MARKER_PATTERN}\))\s+\S/

        def initialize
          reset
        end

        def reset
          @pending_parent_depth = nil
          @active_child_family = nil
        end

        def child_indent_level(text)
          return unless @pending_parent_depth

          marker = self.class.marker_from_text(text)
          return unless marker && self.class.child_marker?(marker)

          family = self.class.child_marker_family(marker)
          if @active_child_family
            @pending_parent_depth + 1 if family == @active_child_family
          elsif self.class.first_child_marker?(marker)
            @pending_parent_depth + 1
          end
        end

        def observe(formatted, in_numbered_note:, paragraph_indent_level:, paragraph_first_line_indent_level:)
          if child_marker_context?(formatted, paragraph_indent_level, paragraph_first_line_indent_level)
            marker = self.class.marker_from_line(formatted)
            @active_child_family = self.class.child_marker_family(marker) if marker
            @pending_parent_depth
          elsif parent_marker_context?(formatted, in_numbered_note, paragraph_indent_level, paragraph_first_line_indent_level)
            @pending_parent_depth = formatted[/\A */].length / 4
            @active_child_family = nil
          else
            reset
          end
        end

        def self.source_marker_line?(line)
          line.to_s.match?(SOURCE_MARKER_LINE_PATTERN)
        end

        def self.marker_text?(text)
          text.match?(MARKER_TEXT_PATTERN)
        end

        def self.alphabetic_marker_text?(text)
          text.match?(ALPHABETIC_MARKER_TEXT_PATTERN)
        end

        def self.roman_marker_text?(text)
          text.match?(ROMAN_MARKER_TEXT_PATTERN)
        end

        def self.marker_line?(line, kind, min_indent: 1)
          parsed_line(line)&.then do |marker|
            marker[:indent_level] >= min_indent && public_send("#{kind}_marker?", marker[:text])
          end
        end

        def self.indent_level(line)
          parsed_line(line)&.fetch(:indent_level)
        end

        def self.marker_from_text(text)
          text.to_s.match(MARKER_LINE_PATTERN)&.[](:marker)
        end

        def self.marker_from_line(line)
          parsed_line(line)&.fetch(:text)
        end

        def self.parsed_line(line)
          return unless (match = line.to_s.match(MARKER_LINE_PATTERN))

          { indent_level: match[:spaces].length / 4, text: match[:marker] }
        end

        def self.parent_marker?(marker)
          (marker.match?(/\A#{ALPHABETIC_DOTTED_MARKER_PATTERN}\z/i) && !roman_child_marker?(marker)) ||
            marker.match?(/\A\((?![ivx]+\))[a-z]+\)\z/i)
        end

        def self.first_parent_marker?(marker)
          marker.match?(/\Aa\.\z/) || marker.match?(/\A\(a\)\z/)
        end

        def self.promotable_parent_marker?(marker)
          first_parent_marker?(marker) || marker.match?(/\A\(A\)\z/)
        end

        def self.uppercase_parent_marker?(marker)
          marker.match?(/\A\([A-Z]\)\z/)
        end

        def self.child_marker?(marker)
          marker.match?(/\A(?:\d+\.|\(\d+\)|#{ROMAN_MARKER_PATTERN}\.|\(#{ROMAN_MARKER_PATTERN}\))\z/)
        end

        def self.roman_child_marker?(marker)
          marker.match?(/\A(?:#{ROMAN_MARKER_PATTERN}\.|\(#{ROMAN_MARKER_PATTERN}\))\z/i)
        end

        def self.first_child_marker?(marker)
          marker.match?(/\A(?:1\.|\(1\)|i\.|\(i\))\z/i)
        end

        def self.child_marker_family(marker)
          marker.match?(/\A(?:\d+\.|\(\d+\))\z/) ? :number : :roman
        end

        private_class_method :parsed_line

        private

        def child_marker_context?(formatted, paragraph_indent_level, paragraph_first_line_indent_level)
          (paragraph_indent_level.positive? && formatted.match?(SOURCE_CHILD_MARKER_LINE_PATTERN)) ||
            (paragraph_indent_level.zero? && paragraph_first_line_indent_level.positive? && self.class.marker_line?(formatted, :child))
        end

        def parent_marker_context?(formatted, in_numbered_note, paragraph_indent_level, paragraph_first_line_indent_level)
          (paragraph_indent_level.positive? && formatted.match?(SOURCE_PARENT_MARKER_LINE_PATTERN)) ||
            (paragraph_indent_level.zero? && paragraph_first_line_indent_level.positive? && self.class.marker_line?(formatted, :parent)) ||
            (in_numbered_note && self.class.marker_line?(formatted, :parent))
        end
      end
    end
  end
end
