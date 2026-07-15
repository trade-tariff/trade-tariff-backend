module XiCnImporter
  class NotesExtractor
    class Formatter
      class TableFormatter
        INDENT = '   '.freeze

        # Renders a Nokogiri table node (EU OJ XHTML content table) as indented
        # govspeak markdown lines. Returns nil if no renderable content is found.
        #
        # Header merging: consecutive header rows (oj-tbl-hdr cells, excluding
        # column-numbering rows like "(1)(2)(3)") are merged column-by-column so
        # that a colspan=2 label row combines with the sub-label row below it to
        # form complete column headers. Column-numbering rows are emitted as the
        # first data row below the separator, matching govspeak convention.
        #
        # Indentation: every line is prefixed with INDENT (3 spaces) so the table
        # renders as continuation content of the enclosing numbered note rather
        # than resetting govspeak's list numbering.
        def call(table, node_text_fn:)
          header_rows = []
          data_rows   = []

          rows_of(table).each do |row|
            cells    = element_children(row, 'td')
            expanded = expand_colspan_cells(cells, node_text_fn:)
            if header_row?(cells) && !column_numbering_row?(cells)
              header_rows << expanded
            else
              data_rows << expanded
            end
          end

          return nil if header_rows.empty? && data_rows.empty?

          col_count = (header_rows + data_rows).map(&:length).max || 0

          merged_header = (0...col_count).map do |i|
            header_rows.map { |row| row[i] || '' }.reject(&:empty?).join(' ')
          end

          lines = []
          lines << markdown_row(merged_header)
          lines << markdown_separator(col_count)
          data_rows.each do |row|
            padded = row + Array.new([col_count - row.length, 0].max, '')
            lines << markdown_row(padded)
          end

          lines.map { |l| "#{INDENT}#{l}" }.join("\n")
        end

        # A content table is one whose OWN cells (not nested sub-tables) carry
        # oj-tbl-hdr or oj-tbl-txt paragraph classes. Uses a shallow check so that
        # structural two-column (label/content) tables containing a nested oj-table
        # are not falsely flagged and collapsed by table_formatter.
        def self.content_table?(node)
          tbody = node.children.find { |n| n.element? && n.name == 'tbody' } || node
          tbody.children.select { |n| n.element? && n.name == 'tr' }.any? do |tr|
            tr.children.select { |n| n.element? && n.name == 'td' }.any? do |td|
              td.children.select { |n| n.element? && n.name == 'p' }.any? do |p|
                (%w[oj-tbl-hdr oj-tbl-txt] & (p['class']&.split || [])).any?
              end
            end
          end
        end

      private

        def header_row?(cells)
          cells.any? do |cell|
            cell.xpath('.//*[local-name()="p"]').any? do |p|
              (p['class']&.split || []).include?('oj-tbl-hdr')
            end
          end
        end

        # A column-numbering row has all non-empty cells containing only
        # parenthetical integers, e.g. "(1)", "(2)", "(3)".
        def column_numbering_row?(cells)
          non_empty = cells.flat_map do |cell|
            cell.xpath('.//*[local-name()="p"]').map { |p| p.text.strip }.reject(&:empty?)
          end
          non_empty.any? && non_empty.all? { |t| t.match?(/\A\(\d+\)\z/) }
        end

        # Expand cells into a flat array, repeating each cell's text by its
        # colspan value so column positions line up across rows.
        def expand_colspan_cells(cells, node_text_fn:)
          cells.flat_map do |cell|
            colspan = (cell['colspan'] || '1').to_i
            text    = cell.xpath('.//*[local-name()="p"]')
                          .map { |p| node_text_fn.call(p) }
                          .reject(&:empty?)
                          .join(' ')
            Array.new(colspan, text)
          end
        end

        def markdown_row(cells)
          "| #{cells.map { |c| markdown_cell(c) }.join(' | ')} |"
        end

        def markdown_separator(col_count)
          "| #{Array.new(col_count, '---').join(' | ')} |"
        end

        def markdown_cell(text)
          text.to_s.gsub(/[\\|]/) { |ch| "\\#{ch}" }
        end

        def rows_of(table)
          tbody = table.children.find { |n| n.element? && n.name == 'tbody' } || table
          tbody.children.select { |n| n.element? && n.name == 'tr' }
        end

        def element_children(node, tag)
          node.children.select { |n| n.element? && n.name == tag }
        end
      end
    end
  end
end
