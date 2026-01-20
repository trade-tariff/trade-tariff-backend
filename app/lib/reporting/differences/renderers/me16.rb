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

        TAB_COLOR = 0x000000

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
          worksheet = workbook.add_worksheet(name)
          worksheet.set_tab_color(TAB_COLOR)
          worksheet.append_row([METRIC], bold_style)
          worksheet.append_row([])
          worksheet.merge_range(1, 0, 1, 4, SUBTEXT, regular_style)
          worksheet.set_row(worksheet.last_row_number, 30, nil)

          worksheet.append_row([])
          worksheet.write_url_opt(
            worksheet.last_row_number,
            0,
            "internal:'Overview'!A1",
            nil,
            'Back to overview',
            nil,
          )
          worksheet.append_row([])

          worksheet.append_row(HEADER_ROW, bold_style)
          worksheet.autofilter(4, 0, 4, 4)
          worksheet.freeze_panes(5, 0)

          (rows || []).compact.each do |row|
            worksheet.append_row(row, regular_style)
          end

          COLUMN_WIDTHS.each_with_index do |width, index|
            worksheet.set_column_width(index, width)
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
