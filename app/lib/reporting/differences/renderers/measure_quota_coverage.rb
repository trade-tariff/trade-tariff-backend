module Reporting
  class Differences
    module Renderers
      class MeasureQuotaCoverage
        # Find all measures that have quota definitions
        #
        # Checks to see if there is at least one definition within each measures validity window
        delegate :workbook, :bold_style, :regular_style, to: :report

        WORKSHEET_NAME = 'Measure quot def coverage'.freeze

        HEADER_ROW = [
          'Measure SID',
          'Commodity code',
          'Quota order number ID',
          'Geographical area',
          'Measure extent',
          'Quota definition extent',
          'New?',
        ].freeze

        TAB_COLOR = 'cccc00'.freeze
        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze
        COLUMN_WIDTHS = [20] * HEADER_ROW.size
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

            (rows || []).each do |row|
              report.increment_count(name)
              sheet.add_row(
                row,
                types: CELL_TYPES,
                style: regular_style,
              )
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
