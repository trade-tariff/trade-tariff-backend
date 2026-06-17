module CustomsTariffImporter
  class NotesExtractor
    class Formatter
      class ParagraphPreprocessor
        COMPACT_NUMBERED_MARKER_PATTERN = /\A([1-9]\d*)\.(?=(?:\([a-z]\)|[A-Z]\.|[[:alpha:]]))/i
        DOTLESS_NUMBERED_NOTE_PATTERN = /\A([1-9]\d*)\s+(?=[A-Z]|\u201C|\()/
        NUMBERED_NOTE_PATTERN = /\A[1-9]\d*\.(?!\d)/
        SOURCE_BULLET_MARKER_PATTERN = /\A\s*(?:-|•|—|–)\s*/

        def initialize(numbering_counters)
          @numbering_counters = numbering_counters
        end

        def call(text, current_paragraph:, last_top_level_note_number:)
          text = normalize_source_bullet_marker(text)
          text = normalize_compact_numbered_marker(text)
          text = normalize_dotless_numbered_note(text, last_top_level_note_number)
          normalize_visual_numbering(text, current_paragraph)
        end

        private

        def normalize_source_bullet_marker(text)
          return text unless text.match?(SOURCE_BULLET_MARKER_PATTERN)

          "- #{text.sub(SOURCE_BULLET_MARKER_PATTERN, '')}"
        end

        def normalize_compact_numbered_marker(text)
          text.sub(COMPACT_NUMBERED_MARKER_PATTERN, '\1. ')
        end

        def normalize_dotless_numbered_note(text, last_top_level_note_number)
          return text unless (match = text.match(DOTLESS_NUMBERED_NOTE_PATTERN))

          note_number = match[1].to_i
          expected_note_number = last_top_level_note_number ? last_top_level_note_number + 1 : 1
          return text unless note_number == expected_note_number

          text.sub(/\A([1-9]\d*)\s+/, '\1. ')
        end

        def normalize_visual_numbering(text, current_paragraph)
          numbering = current_paragraph&.fetch(:numbering, nil)
          return text unless numbering && numbering[:id].positive? && numbering[:level].zero?
          return text if text.match?(NUMBERED_NOTE_PATTERN)

          "#{next_visual_number(numbering)}. #{text}"
        end

        def next_visual_number(numbering)
          key = [numbering[:id], numbering[:level]]
          @numbering_counters[key] = @numbering_counters.fetch(key, 0) + 1
        end
      end
    end
  end
end
