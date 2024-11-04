module Reporting
  class Differences
    module Renderers
      class Me32
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'ME32 candidates'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Measure type',
          'Additional code',
          'Order number',
          'Geography',
          'New?',
        ].freeze

        TAB_COLOR = '00ff00'.freeze

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = [
          30, # Commodity code
          20, # Measure type
          20, # Additional code
          20, # Order number
          20, # Geography
          12, # New
        ].freeze

        AUTOFILTER_CELL_RANGE = 'A5:E5'.freeze
        FROZEN_VIEW_STARTING_CELL = 'A5'.freeze

        METRIC = 'ME32 candidates'.freeze
        SUBTEXT = 'There may be no overlap in time with other measure occurrences with a goods code in the same nomenclature hierarchy which references the same measure type, geo area, order number and additional code.'.freeze

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
