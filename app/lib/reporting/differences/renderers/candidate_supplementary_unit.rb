module Reporting
  class Differences
    module Renderers
      class CandidateSupplementaryUnit
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 :each_chapter,
                 to: :report

        WORKSHEET_NAME = 'Supp unit candidates'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Unit(s)',
        ].freeze

        TAB_COLOR = 0x660066

        COLUMN_WIDTHS = [
          20, # Commodity code
          20, # Unit(s)
        ].freeze

        METRIC = 'Supplementary units that should be present'.freeze
        SUBTEXT = 'Excise etc. may require a supp unit that is not provided'.freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          worksheet = workbook.add_worksheet(name)
          worksheet.set_tab_color(TAB_COLOR)
          worksheet.append_row([METRIC], bold_style)
          worksheet.merge_range(0, 1, 4, 1, SUBTEXT, regular_style)

          worksheet.append_row([FastExcel::URL.new("internal:'Overview'!A1")])
          worksheet.write_string(worksheet.last_row_number, 0, 'Back to overview', nil)

          worksheet.append_row([])
          worksheet.append_row(HEADER_ROW, bold_style)
          worksheet.freeze_panes(1, 0)
          worksheet.autofilter(4, 0, 4, 1)

          (rows || []).each do |row|
            worksheet.append_row(row, regular_style)
            # worksheet.rows.last[1].format = centered_style
          end

          COLUMN_WIDTHS.each_with_index do |width, index|
            worksheet.set_column_width(index, width)
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
