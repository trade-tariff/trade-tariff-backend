module Reporting
  class Differences
    module Renderers
      class MfnMissing
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :each_chapter,
                 to: :report

        WORKSHEET_NAME = 'MFN missing'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Description',
          'New?',
        ].freeze

        TAB_COLOR = '00ff00'.freeze

        COLUMN_WIDTHS = [
          25, # Commodity code (PLS)
          80, # Description
          12, # New
        ].freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
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

        attr_reader :report
      end
    end
  end
end
