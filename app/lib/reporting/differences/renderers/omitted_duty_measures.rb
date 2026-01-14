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

        TAB_COLOR = 0x00FF00

        COLUMN_WIDTHS = [
          30, # Commodity code
          20, # Geographical area id
          20, # Measure type id
          20, # dd/mm
          20, # Order number
          20, # Additional code
          12, # New
        ].freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          worksheet = workbook.add_worksheet(name)
          worksheet.set_tab_color(TAB_COLOR)
          worksheet.append_row(HEADER_ROW, bold_style)
          worksheet.autofilter(0, 0, 0, 5)
          worksheet.freeze_panes(1, 0)

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
      end
    end
  end
end
