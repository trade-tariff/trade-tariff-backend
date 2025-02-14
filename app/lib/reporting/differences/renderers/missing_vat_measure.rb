module Reporting
  class Differences
    module Renderers
      class MissingVatMeasure
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :each_chapter,
                 to: :report

        WORKSHEET_NAME = 'VAT missing'.freeze

        FILTERED_MEASURE_TYPES = Set.new(%w[305]).freeze

        HEADER_ROW = [
          'Commodity code',
          'Description',
          'New?',
        ].freeze

        TAB_COLOR = '666666'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = [
          25, # Commodity code
          80, # Description
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
      end
    end
  end
end
