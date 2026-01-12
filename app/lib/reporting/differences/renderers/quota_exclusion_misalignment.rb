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
          workbook.add_worksheet(name) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row([METRIC], bold_style)
            sheet.freeze_panes(1, 0)

            (rows || []).compact.each do |row|
              sheet.append_row(row)

              sheet.rows.last.tap do |last_row|
                last_row.cells[1].style = centered_style
                last_row.cells[2].style = centered_style
                last_row.cells[3].style = print_style
              end
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
