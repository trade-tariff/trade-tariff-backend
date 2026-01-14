module Reporting
  class Differences
    module Renderers
      class QuotaMissingOrigin
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'Quota with no origins'.freeze

        HEADER_ROW = [
          'Quota order number ID',
          'Quota order number SID',
          'Start date',
          'End date',
          'New?',
        ].freeze

        TAB_COLOR = 0xCCCC00
        COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 25).freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          worksheet = workbook.add_worksheet(name)
          worksheet.set_tab_color(TAB_COLOR)
          worksheet.append_row(HEADER_ROW, bold_style)
          worksheet.freeze_panes(1, 0)

          (rows || []).each do |row|
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
