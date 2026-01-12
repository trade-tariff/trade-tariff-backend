module Reporting
  class Differences
    module Renderers
      class OmittedDutyMeasures
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'Omitted duties'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Geographical area id',
          'Measure type id',
          'dd/mm',
          'Order number',
          'Additional_ code',
          'New?',
        ].freeze

        TAB_COLOR = '00ff00'.freeze

        COLUMN_WIDTHS = [
          30, # Commodity code
          20, # Geographical area id
          20, # Measure type id
          20, # dd/mm
          20, # Order number
          20, # Additional code
          12, # New
        ].freeze

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def add_worksheet(rows)
          workbook.add_worksheet(name) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row([METRIC], bold_style)
            sheet.autofilter(0, 0, 5, 0)
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
