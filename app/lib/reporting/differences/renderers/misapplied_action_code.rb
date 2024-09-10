module Reporting
  class Differences
    module Renderers
      class MisappliedActionCode
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'Misapplied action codes'.freeze

        HEADER_ROW = [
          'Measure sid',
          'Commodity code',
          'Measure type id',
          'Measure type description',
          'Geographical area id',
          'Measure condition sid',
          'Action code',
          'Measure action description',
          'Certificate code',
          'Component sequence number',
          'New?',
        ].freeze

        TAB_COLOR = '00ff00'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze
        COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 20)
        COLUMN_WIDTHS[1] = 40
        COLUMN_WIDTHS.freeze

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
