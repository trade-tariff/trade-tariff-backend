module Reporting
  class Differences
    module Renderers
      class QuotaExclusionMisalignment
        # Find UK measures and quotas which both have geographical area exclusions
        #
        # Checks to see if their exclusions are not aligned/the same
        delegate :workbook,
                 :bold_style,
                 :centered_style,
                 :print_style,
                 to: :report

        WORKSHEET_NAME = 'Exclusion misalignment'.freeze

        HEADER_ROW = [
          'Measure SID',
          'Order number',
          'Commodity',
          'Exclusions (quota, then measure)',
          'New?',
        ].freeze

        TAB_COLOR = 'cccc00'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = [
          20,  # "Measure SID"
          20,  # Order number
          20,  # Commodity
          150, # Exclusions (quota, then measure)
          12, # New
        ].freeze

        FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

        def initialize(report)
          @report = report
        end

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
              sheet.add_row(row, types: CELL_TYPES)

              sheet.rows.last.tap do |last_row|
                last_row.cells[1].style = centered_style
                last_row.cells[2].style = centered_style
                last_row.cells[3].style = print_style
              end
            end

            sheet.column_widths(*COLUMN_WIDTHS)
          end
        end

        def name
          WORKSHEET_NAME
        end

        attr_reader :report
      end
    end
  end
end
