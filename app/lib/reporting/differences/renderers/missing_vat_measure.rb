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

        TAB_COLOR = 0x666666

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
          worksheet = workbook.add_worksheet(name)
          worksheet.set_tab_color(TAB_COLOR)
          worksheet.append_row(HEADER_ROW, bold_style)
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
