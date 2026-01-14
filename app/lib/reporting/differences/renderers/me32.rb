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

        TAB_COLOR = 0x00FF00

        COLUMN_WIDTHS = [
          30, # Commodity code
          20, # Measure type
          20, # Additional code
          20, # Order number
          20, # Geography
          12, # New
        ].freeze

        METRIC = 'ME32 candidates'.freeze
        SUBTEXT = 'There may be no overlap in time with other measure occurrences with a goods code in the same nomenclature hierarchy which references the same measure type, geo area, order number and additional code.'.freeze

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
