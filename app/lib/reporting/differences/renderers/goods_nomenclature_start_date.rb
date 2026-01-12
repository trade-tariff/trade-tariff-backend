module Reporting
  class Differences
    module Renderers
      class GoodsNomenclatureStartDate
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 :uk_goods_nomenclatures,
                 :xi_goods_nomenclatures,
                 to: :report

        WORKSHEET_NAME = 'Start date differences'.freeze

        HEADER_ROW = [
          'Commodity code (PLS)',
          'UK start date',
          'EU start date',
          'New?',
        ].freeze

        TAB_COLOR = 'cc0000'.freeze

        COLUMN_WIDTHS = [
          20, # Commodity code (PLS)
          20, # UK start date
          20, # EU start date
          12, # New
        ].freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row(HEADER_ROW, bold_style)
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
      end
    end
  end
end
