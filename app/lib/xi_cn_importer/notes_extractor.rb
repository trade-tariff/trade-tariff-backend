module XiCnImporter
  class NotesExtractor
    Result = Data.define(:chapters, :sections, :general_rules)

    PART_ONE_PATTERN              = /\APART\s+ONE\z/i
    SCHEDULE_PATTERN              = /SCHEDULE\s+OF\s+CUSTOMS\s+DUTIES/i
    SECTION_HEADING_PATTERN       = /\ASECTION\s+([IVXLCDM]+)\z/i
    CHAPTER_HEADING_PATTERN       = /\ACHAPTER\s+(\d+)\z/i
    ADDITIONAL_NOTES_PATTERN      = /\AAdditional\s+[Nn]otes?\z/i
    SUBHEADING_NOTES_PATTERN      = /\ASubheading\s+[Nn]otes?\z/i
    COMMODITY_TABLE_CLASS         = 'oj-table'.freeze

    def initialize(celex, html_content)
      @celex = celex
      @doc   = Nokogiri::XML(html_content)
    end

    def call
      @chapters      = {}
      @sections      = {}
      @general_rules = {}
      @state         = :scanning

      @current_section     = nil
      @current_chapter     = nil
      @section_lines       = []
      @chapter_lines       = []
      @additional_lines    = []
      @collecting_additional = false

      body_nodes.each { |node| handle_node(node) }

      finalise_section
      finalise_chapter

      Result.new(chapters: @chapters, sections: @sections, general_rules: @general_rules)
    end

  private

    # --- Node dispatch ---

    def body_nodes
      body = @doc.xpath('//*[local-name()="body"]').first
      return [] unless body

      collect_content_nodes(body)
    end

    def collect_content_nodes(node)
      result = []
      node.children.select(&:element?).each do |child|
        case child.name
        when 'p', 'table'
          result << child
        else
          result.concat(collect_content_nodes(child))
        end
      end
      result
    end

    def handle_node(node)
      case @state
      when :scanning           then handle_scanning(node)
      when :in_gri             then handle_in_gri(node)
      when :in_part_two        then handle_in_part_two(node)
      when :in_section         then handle_in_section(node)
      when :collecting_section then handle_collecting_section(node)
      when :in_chapter         then handle_in_chapter(node)
      when :collecting_chapter then handle_collecting_chapter(node)
      when :skipping           then handle_skipping(node)
      end
    end

    # --- State handlers ---

    def handle_scanning(node)
      text = grseq_heading(node)
      @state = :in_gri if text&.match?(PART_ONE_PATTERN)
    end

    def handle_in_gri(node)
      text = grseq_heading(node)
      if text&.match?(SCHEDULE_PATTERN)
        @state = :in_part_two
        return
      end

      extract_gri_rows(node) if note_table?(node)
    end

    def handle_in_part_two(node)
      text = grseq_heading(node)
      return unless text

      if (m = text.match(SECTION_HEADING_PATTERN))
        @current_section = RomanNumerals::Converter.to_decimal(m[1].upcase)
        @section_lines   = []
        @state           = :in_section
      end
    end

    def handle_in_section(node)
      text = grseq_heading(node)

      if (m = text&.match(SECTION_HEADING_PATTERN))
        finalise_section
        @current_section = RomanNumerals::Converter.to_decimal(m[1].upcase)
        @section_lines   = []
        return
      end

      if (m = text&.match(CHAPTER_HEADING_PATTERN))
        finalise_section
        @current_chapter      = sprintf('%02d', m[1].to_i)
        @chapter_lines        = []
        @additional_lines     = []
        @collecting_additional = false
        @state = :in_chapter
        return
      end

      if annotation_header?(node)
        @section_lines << '### Subheading notes' if subheading_notes_header?(node)
        @state = :collecting_section
      end
    end

    def handle_collecting_section(node)
      text = grseq_heading(node)

      if (m = text&.match(SECTION_HEADING_PATTERN))
        finalise_section
        @current_section = RomanNumerals::Converter.to_decimal(m[1].upcase)
        @section_lines   = []
        @state           = :in_section
        return
      end

      if (m = text&.match(CHAPTER_HEADING_PATTERN))
        finalise_section
        @current_chapter      = sprintf('%02d', m[1].to_i)
        @chapter_lines        = []
        @additional_lines     = []
        @collecting_additional = false
        @state = :in_chapter
        return
      end

      if annotation_header?(node)
        @section_lines << '### Additional Notes' if additional_notes_header?(node)
        @section_lines << '### Subheading notes' if subheading_notes_header?(node)
        return
      end

      @section_lines << extract_table_content(node) if note_table?(node)
    end

    def handle_in_chapter(node)
      text = grseq_heading(node)

      if (m = text&.match(SECTION_HEADING_PATTERN))
        finalise_chapter
        @current_section = RomanNumerals::Converter.to_decimal(m[1].upcase)
        @section_lines   = []
        @state           = :in_section
        return
      end

      if (m = text&.match(CHAPTER_HEADING_PATTERN))
        finalise_chapter
        @current_chapter      = sprintf('%02d', m[1].to_i)
        @chapter_lines        = []
        @additional_lines     = []
        @collecting_additional = false
        return
      end

      if annotation_header?(node)
        @collecting_additional = additional_notes_header?(node)
        @chapter_lines << '### Subheading notes' if subheading_notes_header?(node)
        @state = :collecting_chapter
      end
    end

    def handle_collecting_chapter(node)
      if commodity_table?(node)
        finalise_chapter
        @state = :skipping
        return
      end

      text = grseq_heading(node)

      if (m = text&.match(SECTION_HEADING_PATTERN))
        finalise_chapter
        @current_section = RomanNumerals::Converter.to_decimal(m[1].upcase)
        @section_lines   = []
        @state           = :in_section
        return
      end

      if (m = text&.match(CHAPTER_HEADING_PATTERN))
        finalise_chapter
        @current_chapter      = sprintf('%02d', m[1].to_i)
        @chapter_lines        = []
        @additional_lines     = []
        @collecting_additional = false
        @state = :in_chapter
        return
      end

      if annotation_header?(node)
        @collecting_additional = additional_notes_header?(node)
        @chapter_lines << '### Subheading notes' if subheading_notes_header?(node)
        return
      end

      return unless note_table?(node)

      content = extract_table_content(node)
      if @collecting_additional
        @additional_lines << content
      else
        @chapter_lines << content
      end
    end

    def handle_skipping(node)
      text = grseq_heading(node)

      if (m = text&.match(CHAPTER_HEADING_PATTERN))
        @current_chapter      = sprintf('%02d', m[1].to_i)
        @chapter_lines        = []
        @additional_lines     = []
        @collecting_additional = false
        @state = :in_chapter
      elsif (m = text&.match(SECTION_HEADING_PATTERN))
        finalise_section
        @current_section = RomanNumerals::Converter.to_decimal(m[1].upcase)
        @section_lines   = []
        @state           = :in_section
      end
    end

    # --- Finalise ---

    def finalise_section
      return unless @current_section

      content = Formatter.new.call(@section_lines.reject(&:empty?).join("\n\n"))
      @sections[@current_section] = content if content.present?
      @current_section = nil
      @section_lines   = []
    end

    def finalise_chapter
      return unless @current_chapter

      parts = [@chapter_lines.reject(&:empty?).join("\n\n")]
      if @additional_lines.any?
        parts << '### Additional Notes'
        parts << @additional_lines.reject(&:empty?).join("\n\n")
      end

      content = Formatter.new.call(parts.reject(&:empty?).join("\n\n"))
      @chapters[@current_chapter] = content if content.present?
      @current_chapter      = nil
      @chapter_lines        = []
      @additional_lines     = []
      @collecting_additional = false
    end

    # --- Content extraction ---

    def extract_gri_rows(table)
      rows_of(table).each do |row|
        cells = element_children(row, 'td')
        next if cells.length < 2

        label    = cells[0].text.strip
        rule_num = label.chomp('.').strip
        next unless rule_num.match?(/\A\d+\z/)

        content = cells[1].text.strip
        @general_rules[rule_num] = content
      end
    end

    def extract_table_content(table, depth: 0)
      lines = []
      indent = '    ' * depth

      rows_of(table).each do |row|
        cells = element_children(row, 'td')
        next if cells.length < 2

        label   = cells[0].text.strip
        content = extract_cell_content(cells[1], depth:)
        next if label.empty? && content.empty?

        # When a parenthetical label like "(h)" has a sub-table as its only content (no
        # intro <p> text), the sub-table produces leading spaces. Concatenating inline
        # gives "(h)     1. item", which collapse_internal_spaces then flattens to
        # "(h) 1. item". Emit them as separate blocks instead so the formatter can place
        # "(h)" on its own line and number the sub-items at 6 spaces.
        if label.match?(/\A\([a-z]+\)\z/) && content.start_with?(' ')
          lines << "#{indent}#{label}".rstrip
          lines << content
        else
          lines << "#{indent}#{label} #{content}".rstrip
        end
      end

      lines.join("\n\n")
    end

    def extract_cell_content(cell, depth:)
      parts = []

      cell.children.select(&:element?).each do |child|
        if child.name == 'table'
          if Formatter::TableFormatter.content_table?(child)
            markdown = table_formatter.call(child, node_text_fn: method(:paragraph_text_without_footnotes))
            parts << markdown if markdown.present?
          else
            nested = extract_table_content(child, depth: depth + 1)
            parts << nested if nested.present?
          end
        elsif child.name == 'p'
          text = paragraph_text_without_footnotes(child)
          parts << text if text.present?
        elsif child.children.any? { |c| c.element? && c.name == 'table' }
          # Structural wrapper containing sub-tables (e.g. <span> wrapping (A)/(B) sub-tables
          # in Ch11 note 2) — recurse transparently at the same depth.
          nested = extract_cell_content(child, depth:)
          parts << nested if nested.present?
        else
          # Inline text container — may have italic/bold element children but no tables.
          # Extract all descendant text (including from inline children) via XPath.
          # Covers: text-only <span>, <span> with <span class="oj-italic"> for species names, etc.
          text = paragraph_text_without_footnotes(child)
          parts << text if text.present?
        end
      end

      parts.join("\n\n")
    end

    def table_formatter
      @table_formatter ||= Formatter::TableFormatter.new
    end

    # EU OJ XHTML encodes footnote back-references as <a href="#ntr..."> links,
    # e.g. ...(EU) 2018/150 <a href="#ntr190-...">(<span class="oj-super oj-note-tag">190</span>)</a>.
    # The href prefix "#ntr" (note-to-reference) is the EU OJ convention.
    # Plain parenthetical numbers in prose (e.g. "(28) of chromosomes") are bare
    # text with no such <a> ancestor and are preserved.
    def paragraph_text_without_footnotes(node)
      node.xpath('.//text()[not(ancestor::*[local-name()="a" and starts-with(@href, "#ntr")])]').map(&:text).join.gsub(/[\s ]+/, ' ').strip
    end

    def rows_of(table)
      tbody = table.children.find { |n| n.element? && n.name == 'tbody' } || table
      tbody.children.select { |n| n.element? && n.name == 'tr' }
    end

    def element_children(node, tag)
      node.children.select { |n| n.element? && n.name == tag }
    end

    # --- Node predicates ---

    def grseq_heading(node)
      return unless node.name == 'p'
      return unless node['class']&.split&.include?('oj-ti-grseq-1')

      node.text.tr(' ', ' ').strip
    end

    def annotation_header?(node)
      node.name == 'p' && node['class']&.split&.include?('oj-ti-annotation')
    end

    def additional_notes_header?(node)
      paragraph_text_without_footnotes(node).match?(ADDITIONAL_NOTES_PATTERN)
    end

    def subheading_notes_header?(node)
      paragraph_text_without_footnotes(node).match?(SUBHEADING_NOTES_PATTERN)
    end

    def commodity_table?(node)
      node.name == 'table' && node['class']&.split&.include?(COMMODITY_TABLE_CLASS)
    end

    def note_table?(node)
      node.name == 'table' && !commodity_table?(node)
    end
  end
end
