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

        TAB_COLOR = 0xCCCC00

        COLUMN_WIDTHS = [
          20,  # "Measure SID"
          20,  # Order number
          20,  # Commodity
          150, # Exclusions (quota, then measure)
          12, # New
        ].freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          worksheet = workbook.add_worksheet(name)
          worksheet.set_tab_color(TAB_COLOR)
          worksheet.append_row(HEADER_ROW, bold_style)
          worksheet.freeze_panes(1, 0)

          (rows || []).compact.each do |row|
            worksheet.append_row(
              row,
              [
                regular_style,
                centered_style,
                centered_style,
                print_style,
                regular_style,
              ],
            )
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
