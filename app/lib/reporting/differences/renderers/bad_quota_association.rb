module Reporting
  class Differences
    module Renderers
      class BadQuotaAssociation
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 to: :report

        WORKSHEET_NAME = 'Self-referential associations'.freeze

        HEADER_ROW = [
          'Order number (main)',
          'Def. start date (main)',
          'Def. end date (main)',
          'Origin (main)',
          'Order number (sub)',
          'Def. start date (sub)',
          'Def. end date (sub)',
          'Origin (sub)',
          'Relation type',
          'Coefficient',
          'New?',
        ].freeze

        TAB_COLOR = 'cccc00'.freeze

        COLUMN_WIDTHS = [20] * HEADER_ROW.size

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          workbook.add_worksheet(name) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row(HEADER_ROW, bold_style)
            sheet.freeze_panes(1, 0)

            (rows || []).compact.each do |row|
              sheet.append_row(row, format: regular_style)
            end

            COLUMN_WIDTHS.each_with_index do |width, index|
              sheet.set_column_width(index, width)
            end
          end
        end

        def name
          WORKSHEET_NAME
        end
      end
    end
  end
end
