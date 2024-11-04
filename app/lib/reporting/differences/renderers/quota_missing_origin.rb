module Reporting
  class Differences
    module Renderers
      class QuotaMissingOrigin
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'Quota with no origins'.freeze

        HEADER_ROW = [
          'Quota order number ID',
          'Quota order number SID',
          'Start date',
          'End date',
          'New?',
        ].freeze

        TAB_COLOR = 'cccc00'.freeze
        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze
        COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 25).freeze
        FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

        def initialize(report)
          @report = report
        end

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
              sheet.add_row(row, types: CELL_TYPES, style: regular_style)
            end

            sheet.column_widths(*COLUMN_WIDTHS)
          end

          Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
        end

        def name
          WORKSHEET_NAME
        end

        attr_reader :report
      end
    end
  end
end
