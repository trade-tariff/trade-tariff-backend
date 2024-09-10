module Reporting
  class Differences
    module Renderers
      class OmittedDutyMeasures
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'Omitted duties'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Geographical area id',
          'Measure type id',
          'dd/mm',
          'Order number',
          'Additional_ code',
          'New?',
        ].freeze

        TAB_COLOR = '00ff00'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = [
          30, # Commodity code
          20, # Geographical area id
          20, # Measure type id
          20, # dd/mm
          20, # Order number
          20, # Additional code
          12, # New
        ].freeze

        AUTOFILTER_CELL_RANGE = 'A1:F1'.freeze
        FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.sheet_pr.tab_color = TAB_COLOR
            sheet.add_row(HEADER_ROW, style: bold_style)
            sheet.auto_filter = AUTOFILTER_CELL_RANGE
            sheet.sheet_view.pane do |pane|
              pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
              pane.state = :frozen
              pane.y_split = 1
            end

            (rows || []).compact.each do |row|
              report.increment_count(name)
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
