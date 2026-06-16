module CustomsTariffImporter
  class NotesExtractor
    class Formatter
      def initialize
        reset_note_formatting_context
      end

      def extract_paragraphs(xml)
        doc = Nokogiri::XML(xml)
        doc.xpath('/w:document/w:body/*', WORD_NS).flat_map do |node|
          case node.name
          when 'p'
            [paragraph_block(node)]
          when 'tbl'
            table_markdown_lines(node).map { |text| { style: '', text: } }
          else
            []
          end
        end
      end

      def append_note_line(lines, text, paragraph:)
        @current_paragraph = paragraph
        formatted = formatted_note_line(text)
        lines << '' if blank_line_needed_before?(formatted, lines)
        lines << formatted
        update_note_formatting_context(text, formatted)
      end

      def reset_note_formatting_context
        @in_numbered_note = false
        @in_nested_numbered_subnote = false
        @in_source_indented_marker_list = false
        @source_indented_marker_list_closed = false
        @last_top_level_note_number = nil
        @previous_markdown_bullet_indent = nil
        @current_paragraph = nil
        @numbering_counters = {}
      end

      def normalize_note_lines(lines, chapter: false, section: false, current_chapter: nil)
        @current_chapter = current_chapter
        lines = lines.dup
        start_index = 0

        remove_section_note_preamble(lines) if section

        if chapter
          loop do
            next_heading_index = next_note_section_heading_index(lines, start_index)
            normalize_singleton_expression_section(lines, next_content_line_index(lines, start_index), next_heading_index)
            break unless next_heading_index

            start_index = next_heading_index + 1
          end

          normalize_omitted_additional_chapter_note_one(lines)
        end

        normalize_compact_numbered_letter_markers(lines)
        normalize_indented_marker_spacing(lines) if section
        normalize_lettered_paragraph_lists(lines)
        join_split_paragraph_continuations(lines)

        lines
      ensure
        @current_chapter = nil
      end

      private

      def paragraph_block(para)
        style = para.at_xpath('./w:pPr/w:pStyle', WORD_NS)&.attr('w:val').to_s
        {
          style:,
          text: paragraph_text(para),
          indent: paragraph_indent(para),
          first_line_indent: paragraph_first_line_indent(para),
          numbering: paragraph_numbering(para),
        }
      end

      def paragraph_indent(para)
        para.at_xpath('./w:pPr/w:ind', WORD_NS)&.attr('w:left').to_i
      end

      def paragraph_first_line_indent(para)
        para.at_xpath('./w:pPr/w:ind', WORD_NS)&.attr('w:firstLine').to_i
      end

      def paragraph_numbering(para)
        num_pr = para.at_xpath('./w:pPr/w:numPr', WORD_NS)
        return unless num_pr

        {
          id: num_pr.at_xpath('./w:numId', WORD_NS)&.attr('w:val').to_i,
          level: num_pr.at_xpath('./w:ilvl', WORD_NS)&.attr('w:val').to_i,
        }
      end

      def paragraph_text(para)
        plain_text = paragraph_plain_text(para)
        return plain_text if structural_marker?(plain_text)

        para.xpath('.//w:r', WORD_NS).map { |run|
          text = run.xpath('.//w:t', WORD_NS).map(&:text).join
          next if text.empty?

          bold?(run.at_xpath('./w:rPr/w:b', WORD_NS)) ? bold_markdown(text) : text
        }.compact.join.strip
      end

      def bold_markdown(text)
        return text.sub(/\A([1-9]\d*\.\s+)(.+)\z/, '\1**\2**') if text.match?(/\A[1-9]\d*\.(?!\d)\s+\S/)

        "**#{text}**"
      end

      def paragraph_plain_text(para)
        para.xpath('.//w:t', WORD_NS).map(&:text).join.strip
      end

      def structural_marker?(text)
        text.match?(SECTION_PATTERN) ||
          text.match?(CHAPTER_PATTERN) ||
          text.match?(CHAPTER_NOTES_PATTERN) ||
          text.match?(ADDITIONAL_NOTES_PATTERN) ||
          text.match?(ADDITIONAL_SECTION_NOTES_PATTERN) ||
          text.match?(SUBHEADING_NOTES_PATTERN) ||
          text.match?(SECTION_NOTES_PATTERN) ||
          text.match?(GENERAL_RULES_PATTERN) ||
          text.match?(RULE_PATTERN) ||
          text.match?(PART_BOUNDARY_PATTERN)
      end

      def bold?(node)
        return false unless node

        !%w[0 false off].include?(node.attr('w:val').to_s.downcase)
      end

      def table_markdown_lines(table)
        rows = table.xpath('./w:tr', WORD_NS).map { |row| table_row_cells(row) }
        rows.reject!(&:empty?)
        return [] if rows.empty?
        return [rows.flatten.find(&:present?)] if commodity_table?(rows)
        return grouped_table_markdown_lines(rows) if grouped_table_header?(rows)

        header, body_rows = table_header_and_body(rows)
        body = body_rows.map { |row| normalize_table_row(row, header.length) }
        ['', markdown_table_row(header), markdown_table_separator(header.length), *body.map { |row| markdown_table_row(row) }, '']
      end

      def table_row_cells(row)
        row.xpath('./w:tc', WORD_NS).flat_map do |cell|
          text = cell.xpath('./w:p', WORD_NS)
            .map { |para| paragraph_plain_text(para) }
            .reject(&:blank?)
            .join(' ')

          Array.new(table_cell_span(cell), text)
        end
      end

      def table_cell_span(cell)
        cell.at_xpath('./w:tcPr/w:gridSpan', WORD_NS)&.attr('w:val').to_i.then { |span| span.positive? ? span : 1 }
      end

      def commodity_table?(rows)
        rows.flatten.find(&:present?).to_s.match?(COMMODITY_CODE_PATTERN)
      end

      def table_header_and_body(rows)
        header_rows = table_header_rows(rows)
        header = combine_table_header_rows(header_rows)

        [header, rows.drop(header_rows.length)]
      end

      def grouped_table_markdown_lines(rows)
        columns = rows.map(&:length).max
        header = collapse_spanned_cells(normalize_table_row(rows.first, columns))
        markers = collapse_spanned_cells(normalize_table_row(rows.second, columns))
        subheader = normalize_table_row(rows.third, columns)
        body = rows.drop(3).map { |row| normalize_table_row(row, columns) }

        [
          '',
          markdown_table_row(header),
          markdown_table_separator(columns),
          markdown_table_row(markers),
          markdown_table_row(subheader),
          *body.map { |row| markdown_table_row(row) },
          '',
        ]
      end

      def collapse_spanned_cells(row)
        previous = nil
        row.map do |cell|
          collapsed = cell == previous ? '' : cell
          previous = cell
          collapsed
        end
      end

      def grouped_table_header?(rows)
        return false if rows.length < 4
        return false unless rows.first.length == rows.third.length
        return false unless rows.first.chunk_while { |left, right| left == right }.any? { |chunk| chunk.length > 1 }
        return false unless rows.second.compact_blank.all? { |cell| cell.match?(/\A\(\d+\)\z/) }

        rows.third.any?(&:blank?) && rows.third.any?(&:present?)
      end

      def table_header_rows(rows)
        return rows.first(2) if multi_row_header?(rows)

        [collapse_duplicate_header_cells(rows.first)]
      end

      def collapse_duplicate_header_cells(row)
        row.chunk_while { |left, right| left == right }.map(&:first)
      end

      def multi_row_header?(rows)
        return false if rows.length < 3
        return false unless rows.second.any?(&:blank?)

        rows.first.zip(rows.second).any? { |top, lower| top.present? && lower.present? }
      end

      def combine_table_header_rows(rows)
        columns = rows.map(&:length).max
        normalized = rows.map { |row| normalize_table_row(row, columns) }

        Array.new(columns) do |index|
          normalized.map { |row| row[index] }.reject(&:blank?).uniq.join(' ')
        end
      end

      def normalize_table_row(row, columns)
        if columns == 2 && row.length == 3
          [row.first(2).reject(&:blank?).join(' '), row.last]
        else
          row.first(columns).fill('', row.length...columns)
        end
      end

      def markdown_table_row(cells)
        "| #{cells.map { |cell| markdown_table_cell(cell) }.join(' | ')} |"
      end

      def markdown_table_separator(columns)
        markdown_table_row(Array.new(columns, '---'))
      end

      def markdown_table_cell(text)
        text.to_s.strip.gsub(/[\\|]/) { |character| "\\#{character}" }
      end

      def formatted_note_line(text)
        return text if text.blank?

        if @previous_markdown_bullet_indent && bullet_continuation_line?(text)
          return "#{' ' * (@previous_markdown_bullet_indent + 4)}#{text.sub(/\A\s*/, '')}"
        end

        text = normalize_dotless_numbered_note(text)
        text = normalize_visual_numbering(text)
        return markdown_note_section_heading(text) if note_section_heading?(text)
        return nested_numbered_subnote_start(text) if nested_numbered_subnote_start?(text)
        return indented_marker_line(text) if indented_marker?(text)
        return "    #{text}" if nested_numbered_note?(text)
        return text if numbered_note?(text)
        return markdown_bullet_line(text) if source_bullet_line?(text)
        return missing_source_bullet_line(text) if missing_source_bullet_line?(text)
        return "    #{text.sub(/\A\s*/, '')}" if @in_numbered_note

        text
      end

      def update_note_formatting_context(text, formatted)
        return if text.blank?

        if note_section_heading?(text)
          reset_note_formatting_context
          return
        end

        if source_indented_marker_line?(formatted)
          @in_source_indented_marker_list = true
          @source_indented_marker_list_closed = false
          @previous_markdown_bullet_indent = nil
          return
        end

        if source_indented_marker_list_ended?(text)
          @in_source_indented_marker_list = false
          @source_indented_marker_list_closed = true
        end

        if nested_numbered_subnote_start?(text)
          @in_numbered_note = true
          @in_nested_numbered_subnote = true
          @source_indented_marker_list_closed = false
          @previous_markdown_bullet_indent = nil
          return
        end

        if nested_numbered_subnote?(formatted)
          @in_numbered_note = true
          @in_nested_numbered_subnote = true
          @previous_markdown_bullet_indent = nil
          return
        end

        @in_nested_numbered_subnote = false if @in_nested_numbered_subnote && !numbered_note?(formatted)
        if numbered_note?(formatted)
          @in_numbered_note = true
          @source_indented_marker_list_closed = false
          @last_top_level_note_number = formatted[/\A([1-9]\d*)\./, 1].to_i unless @in_nested_numbered_subnote
        end
        @previous_markdown_bullet_indent =
          if markdown_bullet?(formatted)
            formatted[/\A */].length
          elsif @previous_markdown_bullet_indent && bullet_continuation_line?(text)
            formatted[/\A */].length - 4
          end
      end

      def numbered_note?(text)
        text.match?(/\A[1-9]\d*\.(?!\d)/)
      end

      def nested_numbered_note?(text)
        return false unless numbered_note?(text)
        return true if @in_nested_numbered_subnote
        return false unless @in_numbered_note && @last_top_level_note_number

        text[/\A([1-9]\d*)\./, 1].to_i <= @last_top_level_note_number
      end

      def dotless_numbered_note?(text)
        return false unless (match = text.match(/\A([1-9]\d*)\s+(?:[A-Z]|\u201C|\()/))

        note_number = match[1].to_i
        return note_number == 1 if @last_top_level_note_number.nil?

        note_number == @last_top_level_note_number + 1
      end

      def normalize_dotless_numbered_note(text)
        return text unless dotless_numbered_note?(text)

        text.sub(/\A([1-9]\d*)\s+/, '\1. ')
      end

      def normalize_visual_numbering(text)
        numbering = @current_paragraph&.fetch(:numbering, nil)
        return text unless numbering && numbering[:id].positive? && numbering[:level].zero?
        return text if numbered_note?(text)

        number = next_visual_number(numbering)
        "#{number}. #{text}"
      end

      def next_visual_number(numbering)
        key = [numbering[:id], numbering[:level]]
        @numbering_counters[key] = @numbering_counters.fetch(key, 0) + 1
      end

      def nested_numbered_subnote_start?(text)
        text.match?(/\A\([a-z]\)\s+1\.(?!\d)\s+\S/)
      end

      def nested_numbered_subnote_start(text)
        marker, nested_note = text.match(/\A(\([a-z]\))\s+(1\.(?!\d)\s+.+)\z/).captures

        "    #{marker}\n\n    #{nested_note}"
      end

      def markdown_bullet?(text)
        text.match?(/\A\s*-\s+\S/)
      end

      def source_bullet_line?(text)
        text.match?(/\A\s*(?:-|•|—|–)\s*\S/)
      end

      def markdown_bullet_line(text)
        bullet_text = text.sub(/\A\s*(?:-|•|—|–)\s*/, '')
        "#{'    ' if @in_numbered_note}- #{bullet_text}"
      end

      def missing_source_bullet_line?(text)
        @previous_markdown_bullet_indent &&
          paragraph_first_line_indent_level.positive? &&
          text.match?(/\A\S/)
      end

      def missing_source_bullet_line(text)
        "#{' ' * @previous_markdown_bullet_indent}- #{text.sub(/\A\s*/, '')}"
      end

      def indented_marker?(text)
        paragraph_indent_level.positive? && indented_marker_text?(text)
      end

      def indented_marker_line(text)
        indent_level = @in_numbered_note ? indented_marker_indent_level(text) : paragraph_indent_level - 1
        "#{'    ' * indent_level}#{indented_marker_prefix(text)}#{text}"
      end

      def indented_marker_indent_level(text)
        return 1 if alphabetic_marker_text?(text) && !roman_marker_text?(text)
        return 1 if numeric_bracket_marker_text?(text)
        return 1 if roman_bracket_marker_text?(text)

        paragraph_indent_level
      end

      def indented_marker_prefix(text)
        bullet_marker_text?(text) ? '- ' : ''
      end

      def paragraph_indent_level
        (@current_paragraph&.fetch(:indent, 0).to_i / 720).clamp(0, 3)
      end

      def paragraph_first_line_indent_level
        (@current_paragraph&.fetch(:first_line_indent, 0).to_i / 720).clamp(0, 3)
      end

      def indented_marker_text?(text)
        text.match?(/\A(?:[a-z]\.|\([A-Z]\)|\([ivxlcdm]+\)|[ivxlcdm]+\.|\(\d+\))\s+\S/i)
      end

      def alphabetic_marker_text?(text)
        text.match?(/\A[a-z]\.\s+\S/i)
      end

      def roman_marker_text?(text)
        text.match?(/\A(?:i{1,3}|iv|v|vi{0,3}|ix)\.\s+\S/i)
      end

      def numeric_bracket_marker_text?(text)
        text.match?(/\A\(\d+\)\s+\S/)
      end

      def roman_bracket_marker_text?(text)
        text.match?(/\A\((?:i{1,3}|iv|v|vi{0,3}|ix)\)\s+\S/i)
      end

      def bullet_marker_text?(text)
        text.match?(/\A\([A-Z]\)\s+\S/) || roman_marker_text?(text)
      end

      def bullet_continuation_line?(text)
        text.match?(/\A(?:and|or|(?:not\s+)?less than|more than|\d+(?:[.,]\d+)?\s*(?:%|W|mm|cm|g|kg)(?=\s|$))/i)
      end

      def source_indented_marker_list_ended?(text)
        @in_source_indented_marker_list &&
          paragraph_indent_level.zero? &&
          !indented_marker_text?(text)
      end

      def in_closed_source_indented_marker_list?
        @source_indented_marker_list_closed && paragraph_indent_level.zero?
      end

      def note_section_heading?(text)
        plain_note_section_heading?(text) || markdown_note_section_heading?(text)
      end

      def plain_note_section_heading?(text)
        text.match?(ADDITIONAL_NOTES_PATTERN) ||
          text.match?(ADDITIONAL_SECTION_NOTES_PATTERN) ||
          text.match?(SUBHEADING_NOTES_PATTERN)
      end

      def markdown_note_section_heading?(text)
        text.match?(/\A###\s+(?:Additional\s+(?:[Cc]hapter|[Ss]ection)\s+[Nn]otes?|Subheading\s+[Nn]otes?)\z/i)
      end

      def markdown_note_section_heading(text)
        "### #{text}"
      end

      def blank_line_needed_before?(formatted, lines)
        formatted.present? &&
          lines.last.present? &&
          (markdown_bullet?(lines.last) ||
           note_section_heading?(formatted) ||
           markdown_bullet?(formatted) ||
           source_indented_marker_list_ended?(formatted) ||
           closed_source_indented_marker_list_paragraph?(formatted) ||
           source_indented_marker_line?(formatted) ||
           source_indented_marker_continuation?(formatted, lines) ||
           nested_numbered_subnote?(formatted) ||
           numbered_note?(formatted) ||
           standalone_bold_line?(formatted) ||
           consecutive_variable_definition_paragraphs?(lines.last, formatted))
      end

      def consecutive_variable_definition_paragraphs?(previous, formatted)
        variable_definition_paragraph?(previous) && variable_definition_paragraph?(formatted)
      end

      def source_indented_marker_line?(formatted)
        paragraph_indent_level.positive? &&
          formatted.match?(/\A\s+(?:-\s+)?(?:[a-z]\.|\([A-Z]\)|[ivxlcdm]+\.|\(\d+\))\s+\S/i)
      end

      def source_indented_marker_continuation?(formatted, lines)
        return false unless paragraph_indent_level.positive?

        lines.last.to_s.match?(/\A\s+(?:[a-z]\.|\([A-Z]\)|\([ivxlcdm]+\)|[ivxlcdm]+\.|\(\d+\))\s+\S/i) &&
          formatted.match?(/\A\s+\S/)
      end

      def closed_source_indented_marker_list_paragraph?(formatted)
        in_closed_source_indented_marker_list? &&
          !note_section_heading?(formatted) &&
          !numbered_note?(formatted)
      end

      def variable_definition_paragraph?(text)
        text.match?(/\A {4}[“"]?[A-Z][”"]?\s+is\b/)
      end

      def standalone_bold_line?(text)
        text.match?(/\A\s*\*\*[^*].*[^*]\*\*\z/)
      end

      def nested_numbered_subnote?(text)
        text.match?(/\A {4}[1-9]\d*\.(?!\d)\s+\S/)
      end

      def remove_section_note_preamble(lines)
        lines.delete_if { |line| section_note_preamble?(line) }
        lines.shift while lines.any? && lines.first.blank?
      end

      def section_note_preamble?(line)
        line.to_s
          .strip
          .delete_prefix('**')
          .delete_suffix('**')
          .match?(/\AThere are important section (?:note|noted|notes) for this part of the tariff:?\z/i)
      end

      def normalize_indented_marker_spacing(lines)
        index = 1
        while index < lines.length
          if indented_marker_spacing_needed?(lines, index)
            lines.insert(index, '')
            index += 1
          end

          index += 1
        end
      end

      def indented_marker_spacing_needed?(lines, index)
        lines[index - 1].present? && final_indented_marker_line?(lines[index])
      end

      def final_indented_marker_line?(line)
        line.to_s.match?(/\A {4}(?:[a-z]{1,4}[.)]|\([a-z]\)|\([A-Z]\)|\([1-9]\d*\)|[ivxlcdm]+\.)\s+\S/i)
      end

      def normalize_omitted_additional_chapter_note_one(lines)
        additional_heading_index = lines.index { |line| additional_chapter_notes_heading?(line) }
        return unless additional_heading_index

        first_line_index = next_content_line_index(lines, additional_heading_index.to_i + 1)
        return unless first_line_index
        return if numbered_note?(lines[first_line_index])

        next_heading_index = next_note_section_heading_index(lines, additional_heading_index) || lines.length
        return unless lines[(first_line_index + 1)...next_heading_index].any? { |line| line.match?(/\A2\.\s?[A-Z]\./) }

        lines[first_line_index] = "1. #{lines[first_line_index]}"
        ((first_line_index + 1)...next_heading_index).each do |index|
          next if lines[index].blank? || numbered_note?(lines[index])

          lines[index] = "    #{lines[index].sub(/\A\s*/, '')}"
        end

        if lines[first_line_index - 1].present?
          lines.insert(first_line_index, '')
          first_line_index += 1
        end

        lines.insert(first_line_index + 1, '') if lines[first_line_index + 1].present?
      end

      def additional_chapter_notes_heading?(line)
        plain_note_section_heading?(line) && line.match?(ADDITIONAL_NOTES_PATTERN) ||
          line.match?(/\A###\s+Additional\s+[Cc]hapter\s+[Nn]otes?\z/i)
      end

      def normalize_compact_numbered_letter_markers(lines)
        lines.map! { |line| line.sub(/\A([1-9]\d*)\.(\([a-z]\))/, '\1. \2') }
        lines.map! { |line| line.sub(/\A([1-9]\d*)\.([A-Z]\.)/, '\1. \2') }
        lines.map! { |line| line.sub(/\A([1-9]\d*)\.(?=[A-Z][a-z])/, '\1. ') }
      end

      def normalize_lettered_paragraph_lists(lines)
        index = 1
        while index < lines.length
          if lettered_paragraph_list_start?(lines, index)
            index = normalize_lettered_paragraph_list(lines, index)
          else
            index += 1
          end
        end
      end

      def lettered_paragraph_list_start?(lines, index)
        lettered_list_lead_in?(lines[index - 1]) && lettered_paragraph_item?(lines[index], 'a')
      end

      def lettered_list_lead_in?(line)
        line.to_s.match?(/(?:applies only to|does not apply to):\z/)
      end

      def normalize_lettered_paragraph_list(lines, index)
        expected_letter = 'a'

        while index < lines.length && lettered_paragraph_item?(lines[index], expected_letter)
          lines.insert(index, '') if lines[index - 1].present?
          index += 1

          lines[index] = lines[index].sub(/\A {4}/, '    - ')
          expected_letter = expected_letter.next
          index += 1
        end

        lines.insert(index, '') if lines[index].present?
        index
      end

      def lettered_paragraph_item?(line, expected_letter)
        line.match?(/\A {4}(?:#{expected_letter}\.|\(#{expected_letter}\))\s+\S/)
      end

      def join_split_paragraph_continuations(lines)
        index = 1
        while index < lines.length
          if split_paragraph_continuation?(lines[index - 1], lines[index])
            lines[index - 1] = "#{lines[index - 1]} #{lines[index].strip}"
            lines.delete_at(index)
          else
            index += 1
          end
        end
      end

      def split_paragraph_continuation?(previous, current)
        previous.to_s.match?(/\b(?:a|an|and|by|for|in|of|or|the|to|with)\z/i) &&
          current.to_s.match?(/\A {4}[a-z]/)
      end

      def normalize_singleton_expression_section(lines, start_index, end_index)
        end_index ||= lines.length
        return unless start_index
        return unless singleton_expression_section?(lines, start_index, end_index)

        lines[start_index] = lines[start_index].sub(/\A1\.\s*/, '')
        (start_index...end_index).each do |index|
          lines[index] = lines[index].sub(/\A {4}/, '')
        end
      end

      def singleton_expression_section?(lines, start_index, end_index)
        return false unless SINGLETON_EXPRESSION_WRAPPER_CHAPTERS.include?(@current_chapter)
        return false unless lines[start_index]&.match?(
          /\A1\.\s+In this chapter, the following expressions? (?:has|have) the meanings? hereby assigned to (?:it|them):\z/i,
        )

        lines[start_index...end_index].grep(/\A[2-9]\d*\.(?!\d)/).empty?
      end

      def next_note_section_heading_index(lines, start_index)
        ((start_index + 1)...lines.length).find { |index| note_section_heading?(lines[index]) }
      end

      def next_content_line_index(lines, start_index)
        (start_index...lines.length).find { |index| lines[index].present? }
      end
    end
  end
end
