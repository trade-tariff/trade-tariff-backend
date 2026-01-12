module Reporting
  class Differences
    module Renderers
      class IncompleteMeasureCondition
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'Incomplete conditions'.freeze

        DASHBOARD_SECTION = 'Duty and measure-related anomalies'.freeze

        HEADER_ROW = [
          'Measure SID',
          'Measure type ID',
          'Start date',
          'Commodity',
          'Geographical area',
          'Condition duty amount',
          'Action code',
          'Action',
          'New?',
        ].freeze

        TAB_COLOR = '00ff00'.freeze

        COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 20).freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row(HEADER_ROW, bold_style)
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
