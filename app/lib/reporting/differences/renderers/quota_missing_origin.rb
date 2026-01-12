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

        TAB_COLOR = 'cccc00'.freeze
        COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 25).freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row(HEADER_ROW, bold_style)
            sheet.freeze_panes(1, 0)

            (rows || []).each do |row|
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
