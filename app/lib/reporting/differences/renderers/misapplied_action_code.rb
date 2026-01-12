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

        COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 20)
        COLUMN_WIDTHS[1] = 40
        COLUMN_WIDTHS.freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          workbook.add_worksheet(name) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.add_row(HEADER_ROW, bold_style)
            sheet.freeze_panes(1, 0)

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
      end
    end
  end
end
