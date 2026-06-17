module CustomsTariffImporter
  class NotesExtractor
    class Formatter
      class TableFormatter
        def call(table)
          rows = table.xpath('./w:tr', WORD_NS).map { |row| table_row_cells(row) }
          rows.reject!(&:empty?)
          return [] if rows.empty?
          return [rows.flatten.find(&:present?)] if commodity_table?(rows)
          return grouped_table_markdown_lines(rows) if grouped_table_header?(rows)

          header, body_rows = table_header_and_body(rows)
          body = body_rows.map { |row| normalize_table_row(row, header.length) }
          ['', markdown_table_row(header), markdown_table_separator(header.length), *body.map { |row| markdown_table_row(row) }, '']
        end

        private

        def table_row_cells(row)
          row.xpath('./w:tc', WORD_NS).flat_map do |cell|
            text = cell.xpath('./w:p', WORD_NS)
              .map { |para| paragraph_plain_text(para) }
              .reject(&:blank?)
              .join(' ')

            Array.new(table_cell_span(cell), text)
          end
        end

        def paragraph_plain_text(para)
          para.xpath('.//w:t', WORD_NS).map(&:text).join.strip
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
            [combined_two_column_table_label(row.first(2)), row.last]
          else
            row.first(columns).fill('', row.length...columns)
          end
        end

        def combined_two_column_table_label(cells)
          compact_cells = cells.reject(&:blank?)
          return compact_cells.first.to_s if compact_cells.uniq.one?
          return "#{compact_cells.first} (#{compact_cells.second})" if chemical_symbol_name_cells?(compact_cells)

          compact_cells.join(' ')
        end

        def chemical_symbol_name_cells?(cells)
          cells.length == 2 &&
            cells.first.match?(/\A[A-Z][a-z]?\z/) &&
            cells.second.match?(/\A[A-Z][a-z]+\z/)
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
      end
    end
  end
end
