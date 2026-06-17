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
        @paragraph_preprocessor = ParagraphPreprocessor.new(@numbering_counters)
        @marker_trie = MarkerTrie.new
        @table_formatter = TableFormatter.new
      end

      def normalize_note_lines(lines, chapter: false, section: false, current_chapter: nil)
        @current_chapter = current_chapter
        lines = lines.dup
        start_index = 0

        remove_malformed_duplicate_markdown_artifacts(lines)
        remove_note_preamble(lines) if chapter || section

        if chapter
          loop do
            next_heading_index = next_note_section_heading_index(lines, start_index)
            normalize_singleton_expression_section(lines, next_content_line_index(lines, start_index), next_heading_index)
            break unless next_heading_index

            start_index = next_heading_index + 1
          end

          normalize_omitted_additional_chapter_note_one(lines)
        end

        normalize_source_nested_marker_lists(lines)
        normalize_semantic_numeric_marker_lists(lines)
        normalize_plain_marker_code_block_indents(lines)
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
        @table_formatter.call(table)
      end

      def formatted_note_line(text)
        return text if text.blank?

        text = @paragraph_preprocessor.call(
          text,
          current_paragraph: @current_paragraph,
          last_top_level_note_number: @last_top_level_note_number,
        )

        if @previous_markdown_bullet_indent && bullet_continuation_line?(text)
          return "#{' ' * (@previous_markdown_bullet_indent + 4)}#{text.sub(/\A\s*/, '')}"
        end

        return markdown_note_section_heading(text) if note_section_heading?(text)
        return nested_numbered_subnote_start(text) if nested_numbered_subnote_start?(text)
        return indented_marker_line(text) if child_indented_marker?(text)
        return first_line_indented_marker_line(text) if child_first_line_indented_marker?(text)
        return "    #{text}" if nested_numbered_note?(text)
        return text if numbered_note?(text)
        return indented_marker_line(text) if indented_marker?(text)
        return markdown_bullet_line(text) if source_bullet_line?(text)
        return first_line_indented_marker_line(text) if first_line_indented_marker?(text)
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
          @marker_trie.reset
          return
        end

        if nested_numbered_subnote?(formatted)
          @in_numbered_note = true
          @in_nested_numbered_subnote = true
          @previous_markdown_bullet_indent = nil
          @marker_trie.reset
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

        @marker_trie.observe(
          formatted,
          in_numbered_note: @in_numbered_note,
          paragraph_indent_level:,
          paragraph_first_line_indent_level:,
        )
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

      def first_line_indented_marker?(text)
        paragraph_indent_level.zero? &&
          paragraph_first_line_indent_level.positive? &&
          MarkerTrie.marker_text?(text)
      end

      def first_line_indented_marker_line(text)
        indent_level = @in_numbered_note ? (@marker_trie.child_indent_level(text) || 1) : paragraph_first_line_indent_level
        "#{'    ' * indent_level}#{text}"
      end

      def child_first_line_indented_marker?(text)
        first_line_indented_marker?(text) && @marker_trie.child_indent_level(text)
      end

      def indented_marker?(text)
        paragraph_indent_level.positive? && MarkerTrie.marker_text?(text)
      end

      def child_indented_marker?(text)
        indented_marker?(text) && @marker_trie.child_indent_level(text)
      end

      def indented_marker_line(text)
        indent_level = @in_numbered_note ? indented_marker_indent_level(text) : paragraph_indent_level - 1
        "#{'    ' * indent_level}#{indented_marker_prefix(text)}#{text}"
      end

      def indented_marker_indent_level(text)
        return 1 if MarkerTrie.alphabetic_marker_text?(text) && !MarkerTrie.roman_marker_text?(text)
        return @marker_trie.child_indent_level(text) if @marker_trie.child_indent_level(text)

        [paragraph_indent_level, 1].min
      end

      def indented_marker_prefix(text)
        MarkerTrie.roman_marker_text?(text) && @marker_trie.child_indent_level(text) ? '- ' : ''
      end

      def paragraph_indent_level
        (@current_paragraph&.fetch(:indent, 0).to_i / 720).clamp(0, 3)
      end

      def paragraph_first_line_indent_level
        (@current_paragraph&.fetch(:first_line_indent, 0).to_i / 720).clamp(0, 3)
      end

      def bullet_continuation_line?(text)
        text.match?(/\A(?:and|or|(?:not\s+)?less than|more than|\d+(?:[.,]\d+)?\s*(?:%|W|mm|cm|g|kg)(?=\s|$))/i)
      end

      def source_indented_marker_list_ended?(text)
        @in_source_indented_marker_list &&
          paragraph_indent_level.zero? &&
          !MarkerTrie.marker_text?(text)
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
          !consecutive_markdown_table_rows?(lines.last, formatted) &&
          (markdown_bullet?(lines.last) ||
           note_section_heading?(formatted) ||
           markdown_bullet?(formatted) ||
           source_indented_marker_list_ended?(formatted) ||
           closed_source_indented_marker_list_paragraph?(formatted) ||
           source_indented_marker_line?(formatted) ||
           source_indented_paragraph?(formatted) ||
           source_indented_marker_continuation?(formatted, lines) ||
           nested_numbered_subnote?(formatted) ||
           numbered_note?(formatted) ||
           standalone_bold_line?(formatted) ||
           consecutive_variable_definition_paragraphs?(lines.last, formatted))
      end

      def consecutive_markdown_table_rows?(previous, current)
        markdown_table_row?(previous) && markdown_table_row?(current)
      end

      def markdown_table_row?(line)
        line.to_s.strip.match?(/\A\|.*\|\z/)
      end

      def consecutive_variable_definition_paragraphs?(previous, formatted)
        variable_definition_paragraph?(previous) && variable_definition_paragraph?(formatted)
      end

      def source_indented_marker_line?(formatted)
        formatted_source_marker_line?(formatted) &&
          (paragraph_indent_level.positive? || paragraph_first_line_indent_level.positive?)
      end

      def source_indented_marker_continuation?(formatted, lines)
        return false unless paragraph_indent_level.positive?

        MarkerTrie.source_marker_line?(lines.last) &&
          formatted.match?(/\A\s+\S/)
      end

      def source_indented_paragraph?(formatted)
        @in_numbered_note &&
          paragraph_indent_level.positive? &&
          formatted.match?(/\A {4}\S/) &&
          !formatted_source_marker_line?(formatted) &&
          !markdown_table_row?(formatted)
      end

      def formatted_source_marker_line?(formatted)
        MarkerTrie.source_marker_line?(formatted)
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

      def remove_malformed_duplicate_markdown_artifacts(lines)
        lines.delete_if.with_index { |_line, index| malformed_duplicate_markdown_artifact?(lines, index) }
      end

      # Chapter 76 source contains a literal "**Other elements" before the real heading.
      def malformed_duplicate_markdown_artifact?(lines, index)
        text = lines[index].to_s.strip
        return false unless text.match?(/\A\*\*[^*]/) && !text.end_with?('**')

        normalized_note_text(next_content_line(lines, index + 1)) == text.delete_prefix('**').strip
      end

      def next_content_line(lines, start_index)
        lines[start_index..]&.find(&:present?)
      end

      def normalized_note_text(line)
        line.to_s.strip.delete_prefix('**').delete_suffix('**')
      end

      def remove_note_preamble(lines)
        lines.delete_if { |line| note_preamble?(line) }
        lines.shift while lines.any? && lines.first.blank?
      end

      def note_preamble?(line)
        line.to_s
          .strip
          .delete_prefix('**')
          .delete_suffix('**')
          .match?(/\AThere are important (?:(?:chapter|section) )?(?:note|noted|notes) for this part of the tariff:?\z/i)
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
        MarkerTrie.indent_level(line).to_i.positive? && MarkerTrie.marker_from_line(line).present?
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

      def normalize_source_nested_marker_lists(lines)
        index = 0
        while index < lines.length
          if MarkerTrie.marker_line?(lines[index], :promotable_parent)
            index = normalize_source_nested_marker_list(lines, index)
          else
            index += 1
          end
        end
      end

      def normalize_plain_marker_code_block_indents(lines)
        lines.map! do |line|
          plain_deep_marker_line?(line) ? marker_list_line(line, indent_level: 1, bullet: false) : line
        end
      end

      def normalize_semantic_numeric_marker_lists(lines)
        index = 0
        while index < lines.length
          if semantic_numeric_marker_list_lead_in?(lines[index])
            first_item_index = next_content_line_index(lines, index + 1)
            if first_item_index && first_semantic_numeric_marker_line?(lines[first_item_index], lines[index])
              normalize_semantic_numeric_marker_list(lines, first_item_index, line_indent_level(lines[index]))
            end
          end

          index += 1
        end
      end

      def normalize_semantic_numeric_marker_list(lines, start_index, indent_level)
        index = start_index
        while index < lines.length
          index = next_content_line_index(lines, index)
          break unless index && semantic_numeric_marker_line?(lines[index])

          lines[index] = marker_list_line(lines[index], indent_level:, bullet: true)
          index += 1
        end
      end

      def semantic_numeric_marker_list_lead_in?(line)
        line_indent_level(line) == 1 &&
          semantic_numeric_marker_list_lead_in_marker?(line) &&
          line.to_s.strip.end_with?(':')
      end

      def semantic_numeric_marker_list_lead_in_marker?(line)
        marker = MarkerTrie.marker_from_line(line).to_s

        marker.blank? || marker.match?(/\A(?:[a-z]|ij)\.\z/i)
      end

      def first_semantic_numeric_marker_line?(line, lead_in)
        lead_in_indent_level = line_indent_level(lead_in)

        semantic_numeric_marker_line?(line) &&
          [lead_in_indent_level, lead_in_indent_level + 1].include?(MarkerTrie.indent_level(line)) &&
          MarkerTrie.marker_from_line(line) == '(1)'
      end

      def semantic_numeric_marker_line?(line)
        MarkerTrie.indent_level(line).to_i.positive? &&
          MarkerTrie.marker_from_line(line).to_s.match?(/\A\(\d+\)\z/) &&
          !markdown_bullet?(line)
      end

      def line_indent_level(line)
        line.to_s[/\A */].length / 4
      end

      def plain_deep_marker_line?(line)
        MarkerTrie.indent_level(line).to_i > 1 &&
          MarkerTrie.marker_from_line(line).present? &&
          !markdown_bullet?(line) &&
          !dotted_numeric_marker_line?(line)
      end

      def normalize_source_nested_marker_list(lines, start_index)
        parent_indices, child_indices, stop_index, parent_indent_level = source_nested_marker_group(lines, start_index)
        return start_index + 1 if child_indices.empty?
        return start_index + 1 if MarkerTrie.uppercase_parent_marker?(MarkerTrie.marker_from_line(lines[start_index]).to_s) &&
          !MarkerTrie.marker_line?(lines[child_indices.first], :roman_child, min_indent: parent_indent_level.to_i + 1)

        parent_indices.each do |index|
          lines[index] = marker_list_line(lines[index], indent_level: MarkerTrie.indent_level(lines[index]), bullet: true)
        end
        child_indices.each { |index| lines[index] = nested_child_marker_line(lines[index], parent_indent_level:) }
        stop_index
      end

      def nested_child_marker_line(line, parent_indent_level:)
        marker_list_line(
          line,
          indent_level: parent_indent_level.to_i + 1,
          bullet: !dotted_numeric_marker_line?(line),
        )
      end

      def marker_list_line(line, indent_level:, bullet:)
        content = line.sub(/\A */, '').sub(/\A-\s+/, '')
        "#{markdown_indent(indent_level)}#{'- ' if bullet}#{content}"
      end

      def dotted_numeric_marker_line?(line)
        MarkerTrie.marker_from_line(line).to_s.match?(/\A\d+\.\z/)
      end

      def markdown_indent(indent_level)
        '    ' * indent_level.to_i
      end

      def source_nested_marker_group(lines, start_index)
        parent_indices = []
        child_indices = []
        index = start_index
        parent_indent_level = nil

        loop do
          index = next_content_line_index(lines, index)
          break unless index && MarkerTrie.marker_line?(lines[index], :parent)

          parent_indices << index
          parent_indent_level = MarkerTrie.indent_level(lines[index])
          index += 1

          while (index = next_content_line_index(lines, index))
            break if MarkerTrie.marker_line?(lines[index], :parent)
            unless MarkerTrie.marker_line?(lines[index], :child, min_indent: parent_indent_level.to_i + 1)
              return [parent_indices, child_indices, index, parent_indent_level]
            end
            if child_indices.empty? &&
                !MarkerTrie.marker_line?(lines[index], :first_child, min_indent: parent_indent_level.to_i + 1)
              return [parent_indices, [], index, parent_indent_level]
            end

            child_indices << index
            index += 1
          end

          break unless index
        end

        [parent_indices, child_indices, index || lines.length, parent_indent_level]
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

          lines[index] = marker_list_line(lines[index], indent_level: MarkerTrie.indent_level(lines[index]), bullet: true)
          expected_letter = expected_letter.next
          index += 1
        end

        lines.insert(index, '') if lines[index].present?
        index
      end

      def lettered_paragraph_item?(line, expected_letter)
        return false unless MarkerTrie.indent_level(line).to_i.positive?

        [expected_letter, "(#{expected_letter})"].include?(MarkerTrie.marker_from_line(line).to_s.downcase.delete_suffix('.'))
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
