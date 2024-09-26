module Reporting
  class Differences
    module Renderers
      class GoodsNomenclatureEndDate
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 to: :report

        WORKSHEET_NAME = 'End date differences'.freeze

        HEADER_ROW = [
          'Commodity code (PLS)',
          'UK end date',
          'EU end date',
          'New?',
        ].freeze

        TAB_COLOR = 'cc0000'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = [
          20, # Commodity code (PLS)
          20, # UK start date
          20, # EU start date
          12, # New
        ].freeze

        FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.sheet_pr.tab_color = TAB_COLOR
            sheet.add_row(HEADER_ROW, style: bold_style)
            sheet.sheet_view.pane do |pane|
              pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
              pane.state = :frozen
              pane.y_split = 1
            end

            (rows || []).compact.each do |row|
              sheet.add_row(row, types: CELL_TYPES, style: regular_style)
            end

            sheet.column_widths(*COLUMN_WIDTHS)
          end
        end

        def name
          WORKSHEET_NAME
        end
      end
    end
  end
end
