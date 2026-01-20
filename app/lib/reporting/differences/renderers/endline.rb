module Reporting
  class Differences
    module Renderers
      class Endline
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 :uk_goods_nomenclatures,
                 :xi_goods_nomenclatures,
                 to: :report

        WORKSHEET_NAME = 'End line differences'.freeze

        HEADER_ROW = [
          'Commodity code (PLS)',
          'UK endline status',
          'EU endline status',
          'New?',
        ].freeze

        TAB_COLOR = 0xCC0000

        COLUMN_WIDTHS = [
          20, # Commodity code (PLS)
          20, # UK endline status
          20, # EU endline status
          12, # New
        ].freeze

        FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

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
      end
    end
  end
end
