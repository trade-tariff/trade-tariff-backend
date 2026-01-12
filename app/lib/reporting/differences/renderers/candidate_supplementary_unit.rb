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

        TAB_COLOR = '660066'.freeze

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
          workbook.add_worksheet(name:) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row([METRIC], bold_style)
            sheet.merge_range(0, 1, 4, 1)
            sheet.append_row([SUBTEXT], regular_style)
            sheet.append_row([FastExcel::URL.new('internal:Overview!A1')])
            sheet.write_string(2, 0, 'Back to overview', nil)

            sheet.append_row([])
            sheet.append_row(HEADER_ROW, bold_style)
            sheet.freeze_panes(1, 0)
            sheet.autofilter(0, 4, 1, 4)

            (rows || []).each do |row|
              sheet.append_row(row, regular_style)
              sheet.rows.last[1].format = centered_style
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
