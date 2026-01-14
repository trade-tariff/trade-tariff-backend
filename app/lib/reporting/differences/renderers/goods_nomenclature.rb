module Reporting
  class Differences
    module Renderers
      class GoodsNomenclature
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 to: :report

        WORKSHEET_NAME_EU = 'Commodities in EU, not in UK'.freeze
        WORKSHEET_NAME_UK = 'Commodities in UK, not in EU'.freeze

        HEADER_ROW = [
          'SID',
          'Commodity',
          'Product line suffix',
          'Start date',
          'End date',
          'Indentation',
          'End line',
          'Description',
          'New?',
        ].freeze

        TAB_COLOR = 0xCC0000

        COLUMN_WIDTHS = [
          12, # SID
          12, # Commodity
          12, # Product line suffix
          12, # Start date
          12, # End date
          12, # Indentation
          12, # End line
          80, # Description
          12, # New
        ].freeze

        def initialize(source, target, report)
          @source = source
          @target = target
          @name = name
          @report = report
        end

        attr_reader :source, :target, :report

        def add_worksheet(rows)
          worksheet = workbook.add_worksheet(name)
          worksheet.set_tab_color(TAB_COLOR)
          worksheet.append_row(HEADER_ROW, bold_style)
          worksheet.freeze_panes(1, 0)

          (rows || []).each do |row|
            worksheet.append_row(row, regular_style)
            # worksheet.rows.last.tap do |last_row|
            #   last_row.cells[5].format = centered_style # Indentation
            #   last_row.cells[6].format = centered_style # End line
            # end
          end

          COLUMN_WIDTHS.each_with_index do |width, index|
            worksheet.set_column_width(index, width)
          end
        end

        def name
          source == 'uk' ? WORKSHEET_NAME_UK : WORKSHEET_NAME_EU
        end
      end
    end
  end
end
