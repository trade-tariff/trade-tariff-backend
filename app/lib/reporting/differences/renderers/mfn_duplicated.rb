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

        TAB_COLOR = '00ff00'.freeze

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

        FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

        def initialize(report)
          @report = report
        end

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

        attr_reader :report
      end
    end
  end
end
