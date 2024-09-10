module Reporting
  class Differences
    module Renderers
      class Indentation
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 to: :report

        WORKSHEET_NAME = 'Indentation differences'.freeze

        HEADER_ROW = [
          'Commodity code (PLS)',
          'UK indentation',
          'EU indentation',
          'New?',
        ].freeze

        TAB_COLOR = 'cc0000'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = [
          20, # Commodity code (PLS)
          20, # UK indentation
          20, # EU indentation
          12, # New
        ].freeze

        FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.sheet_pr.tab_color = TAB_COLOR
            sheet.add_row(HEADER_ROW, style: bold_style)
            sheet.sheet_view.pane do |pane|
              pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
              pane.state = :frozen
              pane.y_split = 1
            end

            (rows || []).compact.each do |row|
              report.increment_count(name)
              sheet.add_row(row, types: CELL_TYPES, style: regular_style)
              sheet.rows.last.tap do |last_row|
                last_row.cells[1].style = centered_style # UK indentation
                last_row.cells[2].style = centered_style # EU indentation
              end
            end

            sheet.column_widths(*COLUMN_WIDTHS)
          end
        end

        def name
          WORKSHEET_NAME
        end
      end
    end
  end
end
