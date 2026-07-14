module XiCnImporter
  class NotesExtractor
    class Formatter
      ADDITIONAL_NOTES_DIVIDER = '### Additional Notes'.freeze
      NUMBERED_UPPERCASE_SUB_PATTERN = /\A\d+\.\s+\([A-Z]+\)\s/

      def call(content)
        return content if content.blank?

        # Split on the divider string; it may appear at the very start of content.
        raw_parts = content.split(ADDITIONAL_NOTES_DIVIDER, 2)
        main_raw = raw_parts[0].rstrip.presence
        additional_raw = raw_parts[1]&.sub(/\A\n+/, '')

        main_result = main_raw ? format_main_part(main_raw) : nil
        additional_result = additional_raw ? format_additional_part(additional_raw) : nil

        [
          main_result,
          additional_result && "#{ADDITIONAL_NOTES_DIVIDER}\n\n#{additional_result}",
        ].compact.join("\n\n")
      end

      private

      # ── Chapter notes (before "### Additional Notes") ───────────────────────
      # Standard EU formatting artefacts: (a)→a) marker style, punctuation spacing,
      # double spaces. merge_trailing_list_markers runs first because the EU XHTML
      # sometimes places the note number and its sub-marker (e.g. "6. (a)") in one
      # row and the sub-marker's text in the next, producing a dangling marker line.

      def format_main_part(content)
        return '' if content.blank?

        lines = content.split("\n")
        lines = normalise_whitespace_lines(lines)
        lines = normalise_deep_indentation(lines)
        lines = merge_trailing_list_markers(lines)
        lines.map! { |l| convert_emdash_bullet(l) }
        lines = normalise_uppercase_sub_note_indentation(lines)
        lines.map! { |l| normalise_list_marker(l) }
        lines = align_orphaned_list_markers(lines)
        lines = merge_list_item_continuations(lines)
        lines = indent_note_continuations(lines)
        lines = collapse_multiple_blanks(lines)
        lines.map! { |l| strip_punctuation_spacing(l) }
        lines.map! { |l| collapse_internal_spaces(l) }
        lines.join("\n")
      end

      # ── Additional Notes section ──────────────────────────────────────────────
      # EU XHTML nests Additional Notes in deeply-indented two-column tables.
      # Markers like (a) stay in their parenthesised form (govspeak convention
      # for Additional Notes differs from chapter notes).

      def format_additional_part(content)
        return '' if content.blank?

        lines = content.split("\n")
        lines = normalise_whitespace_lines(lines)
        lines = normalise_deep_indentation(lines)
        lines = merge_isolated_markers(lines)
        lines = collapse_multiple_blanks(lines)
        lines.map! { |l| convert_emdash_bullet(l) }
        lines = normalise_additional_notes_indentation(lines)
        lines.map! { |l| strip_punctuation_spacing(l) }
        lines.map! { |l| collapse_internal_spaces(l) }
        lines.join("\n")
      end

      # ── Shared helpers ────────────────────────────────────────────────────────

      # EU source uses (a) (b) (c) / (i) (ii) (iii) style; govspeak expects a) b) c) / i) ii) iii)
      # Applied to chapter notes only — Additional Notes keep the parenthesised form.
      # The (?:\d+\.\s+)? group also handles markers that follow a note number on the same
      # line (e.g. "6. (a) text" → "6. a) text") after merge_trailing_list_markers has run.
      def normalise_list_marker(line)
        line.gsub(/\A(\s*(?:\d+\.\s+)?)\(([a-z]+)\)(\s)/, '\1\2)\3')
      end

      # EU publication leaves a space before punctuation after heading refs: "0301 ," → "0301,"
      # Also catches space before closing parenthesis ("0210 )") and colon.
      def strip_punctuation_spacing(line)
        line.gsub(/(\w) +([,;.:)])/, '\1\2')
      end

      # Collapse double spaces left by stripped heading-ref trailing spaces: "0307  or" → "0307 or"
      def collapse_internal_spaces(line)
        line.sub(/\A(\s*)(.+)\z/m) { ::Regexp.last_match(1) + ::Regexp.last_match(2).gsub(/ {2,}/, ' ') }
      end

      # Treat lines containing only whitespace as blank lines (EU XHTML table whitespace artefact)
      def normalise_whitespace_lines(lines)
        lines.map { |l| l.strip.empty? ? '' : l }
      end

      # EU XHTML uses deeply nested two-column tables; extracted content can have 13+ spaces
      # of base indentation as an artefact of depth tracking. Strip the common base indent
      # to restore readable relative nesting.
      def normalise_deep_indentation(lines)
        deep_lines = lines.select { |l| l.match?(/\A {13,}\S/) }
        return lines if deep_lines.empty?

        min_indent = deep_lines.map { |l| l[/\A( *)/, 1].length }.min

        lines.map do |l|
          current_indent = l[/\A( *)/, 1].length
          current_indent >= min_indent ? (' ' * (current_indent - min_indent)) + l.lstrip : l
        end
      end

      # EU XHTML nests (A)/(B) sub-tables one level deeper than the enclosing note table,
      # and their contents (a)/(b) sub-items, continuation paragraphs) one level deeper still.
      # When a note opens with "N. (A) text", items at ≥ 4 spaces of raw indentation are
      # XHTML artefacts — govspeak wants them at 3 spaces (the standard continuation indent
      # for a numbered list). Guards: empty lines and table rows (|) pass through unchanged.
      # Resets on any new numbered note or "### …" header.
      # First confirmed: Chapter 11 note 2 (cereal milling classification).
      def normalise_uppercase_sub_note_indentation(lines)
        inside = false
        lines.map do |line|
          stripped = line.lstrip
          current_indent = line[/\A( *)/, 1].length

          if stripped.empty?
            line
          elsif stripped.start_with?('###')
            inside = false
            line
          elsif current_indent.zero? && stripped.match?(NUMBERED_UPPERCASE_SUB_PATTERN)
            inside = true
            line
          elsif current_indent.zero? && stripped.match?(/\A\d+\./)
            inside = false
            line
          elsif inside && current_indent >= 4 && !stripped.start_with?('|')
            "   #{stripped}"
          else
            line
          end
        end
      end

      # After a chapter-note list, EU XHTML can emit a closing paragraph at 0 indent that
      # belongs to the enclosing numbered note. Track the last seen list indent; any 0-indent
      # paragraph that isn't a new numbered note or section header gets raised to that indent.
      # Also raises continuation paragraphs that appear *before* the sub-list (when list_indent
      # is still 0) — EU XHTML emits these at 0 indent but govspeak needs them at 3 spaces so
      # the ordered-list counter isn't reset and the following sub-items aren't parsed as a
      # code block. First confirmed: Chapter 12 notes 3 and 4.
      # Resets on "2. Next note" (digit) or "### Subheading notes" headers.
      def indent_note_continuations(lines)
        list_indent = 0
        inside_uppercase_sub = false
        inside_numbered_note = false
        uppercase_sub_indent = 0
        uppercase_dot_indent = 0
        note_indent = 3

        lines.map do |line|
          stripped       = line.lstrip
          current_indent = line[/\A( *)/, 1].length

          if stripped.start_with?('###')
            list_indent = 0
            inside_uppercase_sub = false
            inside_numbered_note = false
            uppercase_sub_indent = 0
            uppercase_dot_indent = 0
            note_indent = 3
            line
          elsif stripped.match?(NUMBERED_UPPERCASE_SUB_PATTERN) && current_indent.zero?
            inside_uppercase_sub = true
            inside_numbered_note = true
            list_indent = 0
            uppercase_sub_indent = 0
            uppercase_dot_indent = 0
            note_indent = stripped.match(/\A(\d+)\./)[1].length + 2
            line
          elsif stripped.match?(/\A\d+\./) && current_indent.zero?
            list_indent = 0
            inside_uppercase_sub = false
            inside_numbered_note = true
            uppercase_sub_indent = 0
            uppercase_dot_indent = 0
            note_indent = stripped.match(/\A(\d+)\./)[1].length + 2
            line
          elsif current_indent.zero? && inside_uppercase_sub && stripped.match?(/\A\([A-Z]+\)\s/)
            "   #{stripped}"
          elsif current_indent < note_indent && inside_numbered_note && list_indent.zero? && !stripped.empty?
            if stripped.start_with?('|')
              line
            elsif stripped.match?(/\A[a-z]+\) /) && current_indent.zero?
              # Letter item at column 0 — leave in place (correct position under a
              # single-digit note, or will be handled by align_orphaned_list_markers).
              line
            else
              ' ' * note_indent + stripped
            end
          elsif stripped.match?(/\A\([A-Z]+\)\s/) && current_indent.positive?
            uppercase_sub_indent = current_indent
            list_indent = 0
            line
          elsif line.match?(/\A {1,}[a-z]+\) /)
            if uppercase_sub_indent.positive? && current_indent > uppercase_sub_indent
              list_indent = uppercase_sub_indent
              ' ' * uppercase_sub_indent + stripped
            elsif uppercase_dot_indent.positive?
              # Inside A./B. dot-sub-section: clamp to uppercase_dot_indent + 2 to keep
              # below the govspeak code-block threshold (8+ spaces inside a numbered list
              # item triggers a scrollable pre block).
              list_indent = uppercase_dot_indent + 2
              inside_uppercase_sub = false
              ' ' * list_indent + stripped
            elsif list_indent.positive? && current_indent > list_indent
              # Letter-list item arrived deeper than the current list level (e.g. roman numeral
              # ii)/iii) at 8 spaces when the enclosing a)/b) list is at 4 spaces). Pull back.
              ' ' * list_indent + stripped
            else
              list_indent = current_indent
              inside_uppercase_sub = false
              line
            end
          elsif stripped.match?(/\A[A-Z]\.\s/) && current_indent.positive?
            uppercase_dot_indent = current_indent
            line
          elsif current_indent > list_indent && list_indent.positive? && uppercase_dot_indent.zero? && stripped.match?(/\A\(\d+\) /)
            # Pull over-deep (N) items back to list_indent — but NOT inside an A./B.
            # dot-sub-section where they are legitimately one level below the letter-list.
            ' ' * list_indent + stripped
          elsif current_indent > list_indent && list_indent.positive? && uppercase_dot_indent.positive? && stripped.match?(/\A\(\d+\) /)
            # Inside A./B.: clamp (N) items to the same level as the letter-list
            # (uppercase_dot_indent + 2) so they don't trigger a govspeak code block.
            ' ' * (uppercase_dot_indent + 2) + stripped
          elsif current_indent > list_indent && list_indent.positive? && stripped.start_with?('- ')
            ' ' * list_indent + stripped
          elsif current_indent > list_indent && list_indent.positive? && !stripped.empty?
            stripped.start_with?('|') ? line : ' ' * list_indent + stripped
          elsif current_indent < list_indent && list_indent.positive? && stripped.start_with?('|')
            ' ' * list_indent + stripped
          elsif current_indent.zero? && list_indent.positive? && !stripped.empty?
            if stripped.match?(/\A\([a-z]+\)/) || stripped.start_with?('|')
              line
            elsif uppercase_dot_indent.positive?
              # Inside an A./B. dot-sub-section: raise 0-indent continuation to the
              # sub-section level rather than all the way to the letter-list indent.
              ' ' * uppercase_dot_indent + stripped
            else
              ' ' * list_indent + stripped
            end
          else
            line
          end
        end
      end

      # EU XHTML can produce the first item in a chapter-note sub-list at 0 indent while
      # all sibling items are at a consistent positive indent. Walk consecutive list-marker
      # pairs; if the first is at 0 and the next is at positive indent, raise the first
      # to match.
      def align_orphaned_list_markers(lines)
        markers = lines.each_with_index
                       .select { |l, _| l.match?(/\A *[a-z]+\) /) }
                       .map { |l, i| [i, l[/\A( *)/, 1].length] }
        return lines if markers.empty?

        result = lines.dup
        markers.each_cons(2) do |(idx_a, indent_a), (_, indent_b)|
          next unless indent_a.zero? && indent_b.positive?

          result[idx_a] = ' ' * indent_b + result[idx_a]
        end
        result
      end

      # EU XHTML can split a list item's sentence across two table rows: the item text
      # (e.g. "b) to improve… syrup),") lands in one row and the continuation clause
      # ("provided that they retain…") lands at 0 indent in the next row. Merge the
      # continuation back onto the list item line.
      # Guard: skip if the next non-blank is another list item or a numbered note.
      def merge_list_item_continuations(lines)
        result = []
        i = 0
        while i < lines.length
          line = lines[i]
          if line.match?(/\A {1,}[a-z]+\) /) && line.rstrip.end_with?(',')
            next_idx = (i + 1...lines.length).find { |j| lines[j].strip.present? }
            if next_idx
              next_stripped = lines[next_idx].strip
              next_indent   = lines[next_idx][/\A( *)/, 1].length
              if next_indent.zero? &&
                  !next_stripped.match?(/\A\d+\./) &&
                  !next_stripped.match?(/\A[a-z]+\) /) &&
                  !next_stripped.match?(/\A\([a-z]+\)/)
                result << "#{line.rstrip} #{next_stripped}"
                i = next_idx + 1
                next
              end
            end
          end
          result << line
          i += 1
        end
        result
      end

      # In chapter notes, the EU XHTML sometimes places a note number and its sub-marker
      # in the same row ("6. (a)") with no text, and the sub-marker's content in the
      # next row. This produces a dangling line whose stripped form is exactly a
      # note-number + parenthetical marker (e.g. "6. (a)") or just a bare "(a)".
      # Merge it with the following non-empty line so normalise_list_marker can then
      # convert the whole "6. (a) text" → "6. a) text" in one pass.
      def merge_trailing_list_markers(lines)
        result = []
        i = 0
        while i < lines.length
          line = lines[i]
          if line.rstrip.match?(/\A\s*(?:\d+\.\s+)?\([a-zA-Z]+\)\z/)
            next_idx = (i + 1...lines.length).find { |j| lines[j].strip.present? }
            if next_idx
              result << "#{line.rstrip} #{lines[next_idx].strip}"
              i = next_idx + 1
              next
            end
          end
          result << line
          i += 1
        end
        result
      end

      # EU two-column tables sometimes emit the marker (e.g. "(a)", "B.", "—", "1. A.")
      # in one row and the content in the next, producing isolated-marker lines.
      # Merge each such line with the following non-empty line — UNLESS that line is
      # itself an isolated marker (e.g. (h) followed by 1.), in which case both should
      # remain on separate lines so each is processed independently.
      def merge_isolated_markers(lines)
        result = []
        i = 0
        while i < lines.length
          line = lines[i]
          if isolated_marker_line?(line)
            next_idx = (i + 1...lines.length).find { |j| lines[j].present? }
            # Also skip merging when the next line is an already-populated indented numbered
            # sub-item (e.g. "    1. 'crop'...") — the extractor placed the parenthetical
            # label alone on a line and the numbered content on the next, and they must stay
            # separate so normalise_additional_notes_indentation can place them at 6 spaces.
            if next_idx && !isolated_marker_line?(lines[next_idx]) && !lines[next_idx].match?(/\A +\d+\./)

              indent = line[/\A( *)/, 1]
              result << "#{indent}#{line.strip} #{lines[next_idx].strip}"
              i = next_idx + 1
              next
            end
          end
          result << line
          i += 1
        end
        result
      end

      # Collapse runs of consecutive blank lines to a single blank line
      def collapse_multiple_blanks(lines)
        result = []
        prev_blank = false
        lines.each do |line|
          if line.empty?
            result << '' unless prev_blank
            prev_blank = true
          else
            result << line
            prev_blank = false
          end
        end
        result
      end

      # In Additional Notes, re-anchor the indentation to govspeak convention.
      # Stateful: tracks whether we are inside a sub-section so that continuation
      # paragraphs (XHTML rows with empty label cells, arriving at 0-1 space indent)
      # are correctly indented to 3 spaces rather than left at the margin.
      #
      #   (a)/(b)/… markers                → 3 spaces
      #   uppercase sub-section B./C./…    → 3 spaces (siblings of A. under the same note)
      #   N. X. numbered note (e.g. 2. A.) → 0 spaces, resets sub-section context
      #   indented bullet points (- …)     → 6 spaces (one level inside (a)/(b))
      #   indented numeric sub-items 1./2. → 6 spaces
      #   continuation lines at 0-1 spaces while inside a sub-section → 3 spaces
      #
      # NOTE: convert_emdash_bullet must run before this method so — bullets are already - .
      def normalise_additional_notes_indentation(lines)
        inside_sub_section = false
        inside_numbered_note = false
        inside_dash_bullet = false
        note_indent = 3

        lines.map do |line|
          stripped = line.lstrip
          current_indent = line[/\A( *)/, 1].length

          if stripped.match?(/\A\([a-z]+\)(?:[\s,]|\z)/)
            inside_sub_section = true
            inside_dash_bullet = false
            ' ' * note_indent + stripped
          elsif stripped.match?(/\A[A-Z]\.(?:\s|\z)/)
            inside_sub_section = true
            inside_dash_bullet = false
            ' ' * note_indent + stripped
          elsif stripped.match?(/\A\d+\.\s+[A-Z]\./)
            inside_sub_section = false
            inside_numbered_note = true
            inside_dash_bullet = false
            note_indent = stripped.match(/\A(\d+)\./)[1].length + 2
            line
          elsif stripped.match?(/\A\d+\.\s/) && current_indent.zero?
            inside_numbered_note = true
            inside_sub_section = false
            inside_dash_bullet = false
            note_indent = stripped.match(/\A(\d+)\./)[1].length + 2
            line
          elsif current_indent.positive? && stripped.start_with?('- ')
            inside_dash_bullet = true
            "      #{stripped}"
          elsif current_indent.positive? && stripped.match?(/\A\d+\./)
            "      #{stripped}"
          elsif line.empty?
            line
          elsif inside_dash_bullet && !inside_sub_section && !stripped.empty? && current_indent < 6
            "         #{stripped}"
          elsif inside_sub_section && current_indent < note_indent && !stripped.match?(/\A\d/)
            ' ' * note_indent + stripped
          elsif inside_numbered_note && current_indent < note_indent && !stripped.match?(/\A\d/) && !stripped.start_with?('- ')
            ' ' * note_indent + stripped
          elsif current_indent > 6
            # Over-indented plain text from XHTML nesting artefacts (e.g. continuation
            # paragraphs nested one level deeper than the bullet list they follow).
            # Cap at 6 spaces — the deepest meaningful indent in Additional Notes.
            "      #{stripped}"
          else
            line
          end
        end
      end

      # EU source uses — (em-dash) as a list bullet; convert to govspeak markdown dash
      def convert_emdash_bullet(line)
        line.gsub(/\A(\s*)— /, '\1- ')
      end

      ISOLATED_MARKER_PATTERN = /\A(?:\d+\.\s+[A-Z]\.|\d+\.\s+\([a-z]+\)|\([a-z]+\)|[A-Z]\.|—|\d+\.)\z/

      def isolated_marker_line?(line)
        stripped = line.strip
        stripped.present? && stripped.match?(ISOLATED_MARKER_PATTERN)
      end
    end
  end
end
