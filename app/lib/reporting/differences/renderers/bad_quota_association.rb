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

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = [20] * HEADER_ROW.size

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
