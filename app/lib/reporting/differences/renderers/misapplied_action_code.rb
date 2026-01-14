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

        TAB_COLOR = 0x00FF00

        COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 20)
        COLUMN_WIDTHS[1] = 40
        COLUMN_WIDTHS.freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

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
      end
    end
  end
end
