module Reporting
  class Differences
    module Renderers
      class MissingVatMeasure
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :each_chapter,
                 to: :report

        WORKSHEET_NAME = 'VAT missing'.freeze

        FILTERED_MEASURE_TYPES = Set.new(%w[305]).freeze

        HEADER_ROW = [
          'Commodity code',
          'Description',
          'New?',
        ].freeze

        TAB_COLOR = '666666'.freeze

        COLUMN_WIDTHS = [
          25, # Commodity code
          80, # Description
          12, # New
        ].freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

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
      end
    end
  end
end
