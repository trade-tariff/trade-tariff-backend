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
          workbook.add_worksheet(name) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row([METRIC], bold_style)
            sheet.append_row([SUBTEXT], regular_style)
            sheet.set_row(sheet.last_row_number, height: 30)
            sheet.merge_range(0, 1, 4, 1)

            sheet.append_row([FastExcel::URL.new('internal:Overview!A1')])
            sheet.write_string(sheet.last_row_number, 0, 'Back to overview', nil)

            sheet.add_row([])

            sheet.add_row(HEADER_ROW, bold_style)
            sheet.autofilter(0, 4, 5, 4)
            sheet.freeze_panes(5, 0)

            (rows || []).compact.each do |row|
              sheet.add_row(row, regular_style)
            end

            COLUMN_WIDTHS.each_with_index do |width, index|
              sheet.set_column_width(index, width)
            end
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
