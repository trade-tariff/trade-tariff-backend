module Reporting
  class Differences
    module Renderers
      class MfnDuplicated
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'Duplicate MFNs'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Headline',
          'MFN 1 - SID',
          'MFN 1 - Add code',
          'MFN 1 - Duty',
          'MFN 1 - Measure type',
          'MFN 2 - SID',
          'MFN 2 - Add code',
          'MFN 2 - Duty',
          'MFN 2 - Measure type',
          'New?',
        ].freeze

        TAB_COLOR = 0x00FF00

        COLUMN_WIDTHS = [
          25, # Commodity code
          40, # Headline
          20, # MFN 1 - SID
          20, # MFN 1 - Add code
          20, # MFN 1 - Duty
          20, # MFN 1 - Measure type
          20, # MFN 2 - SID
          20, # MFN 2 - Add code
          20, # MFN 2 - Duty
          20, # MFN 2 - Measure type
          12, # New
        ].freeze

        def initialize(report)
          @report = report
        end

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

        attr_reader :report
      end
    end
  end
end
