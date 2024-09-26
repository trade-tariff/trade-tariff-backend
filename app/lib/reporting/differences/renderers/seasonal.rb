module Reporting
  class Differences
    module Renderers
      class Seasonal
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'Seasonal duties'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Geo area',
          'Measure type',
          'Start date',
          'End date',
          'Duty status',
          'New?',
        ].freeze

        TAB_COLOR = '00ff00'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = ([20] * 5 + [40]).freeze

        AUTOFILTER_CELL_RANGE = 'A5:F5'.freeze
        FROZEN_VIEW_STARTING_CELL = 'A6'.freeze

        METRIC = 'Seasonal duties'.freeze
        SUBTEXT = 'Seasonal duties that should be in place (according to the reference documents) but cannot be found'.freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.sheet_pr.tab_color = TAB_COLOR
            sheet.add_row([METRIC], style: bold_style)
            subtext_row = sheet.add_row([SUBTEXT], style: regular_style)
            subtext_row.height = 30
            sheet.merge_cells('A2:E2')
            sheet.add_row(['Back to overview'])
            sheet.add_hyperlink(
              location: "'Overview'!A1",
              target: :sheet,
              ref: sheet.rows.last[0].r,
            )
            sheet.add_row([])

            sheet.add_row(HEADER_ROW, style: bold_style)
            sheet.auto_filter = AUTOFILTER_CELL_RANGE
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
