module Reporting
  class Differences
    module Renderers
      class MeasureQuotaCoverage
        # Find all measures that have quota definitions
        #
        # Checks to see if there is at least one definition within each measures validity window
        delegate :workbook,
                 :bold_style,
                 :regular_style,
                 to: :report

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

        COLUMN_WIDTHS = [20] * HEADER_ROW.size

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          workbook.add_worksheet(name) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.add_row(HEADER_ROW, bold_style)
            sheet.freeze_panes(1, 0)

            (rows || []).compact.each do |row|
              sheet.append_row(row, regular_style)
            end

            COLUMN_WIDTHS.each_with_index do |width, index|
              sheet.set_column_width(index, width)
            end
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
