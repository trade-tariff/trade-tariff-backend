module Reporting
  class Differences
    module Renderers
      class Me16
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'ME16 candidates'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Measure type',
        ].freeze

        TAB_COLOR = '000000'.freeze

        COLUMN_WIDTHS = [
          30, # Commodity code
          20, # Measure type
        ].freeze

        METRIC = 'ME16 candidates'.freeze
        SUBTEXT = 'This indicates that there are comm codes where a duty exists both with and without additional codes, which breaks ME16'.freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row([METRIC], bold_style)
            subtext_row = sheet.append_row([SUBTEXT], regular_style)
            subtext_row.height = 30
            sheet.merge_range(0, 1, 4, 1)

            sheet.append_row([FastExcel::URL.new('internal:Overview!A1')])
            sheet.write_string(2, 0, 'Back to overview')

            sheet.append_row([])

            sheet.append_row(HEADER_ROW, bold_style)
            sheet.autofilter(0, 4, 1, 4)
            sheet.freeze_panes(4, 0)

            (rows || []).compact.each do |row|
              sheet.append_row(row, regular_style)
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
