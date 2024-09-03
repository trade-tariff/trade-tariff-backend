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

        TAB_COLOR = 'cc0000'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

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

        FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

        def initialize(source, target, report)
          @source = source
          @target = target
          @name = name
          @report = report
        end

        attr_reader :source, :target, :report

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
              sheet.add_row(row, types: CELL_TYPES, style: regular_style)
              sheet.rows.last.tap do |last_row|
                last_row.cells[5].style = centered_style # Indentation
                last_row.cells[6].style = centered_style # End line
              end
            end

            sheet.column_widths(*COLUMN_WIDTHS)
          end
        end

        def name
          source == 'uk' ? WORKSHEET_NAME_UK : WORKSHEET_NAME_EU
        end
      end
    end
  end
end
