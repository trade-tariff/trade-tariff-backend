module Reporting
  class Differences
    class QuotaMissingOrigin
      delegate :workbook,
               :regular_style,
               :bold_style,
               :each_chapter,
               to: :report

      HEADER_ROW = [
        'Quota order number ID',
        'Quota order number SID',
        'Start date',
        'End date',
      ].freeze

      TAB_COLOR = 'cccc00'.freeze
      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze
      COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 25).freeze
      AUTOFILTER_CELL_RANGE = 'A1:B1'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(name, report)
        @name = name
        @report = report
      end

      def add_worksheet
        workbook.add_worksheet(name:) do |sheet|
          sheet.sheet_pr.tab_color = TAB_COLOR
          sheet.add_row(HEADER_ROW, style: bold_style)
          sheet.auto_filter = AUTOFILTER_CELL_RANGE
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
            pane.state = :frozen
            pane.y_split = 1
          end

          each_row do |row|
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      private

      attr_reader :name, :report

      def each_row
        TimeMachine.at(report.as_of) do
          QuotaOrderNumber
            .actual
            .association_left_join(:quota_order_number_origins)
            .where(quota_order_numbers__quota_order_number_id: /^05/)
            .where(quota_order_number_origins__quota_order_number_origin_sid: nil)
            .select_map(
              %i[
                quota_order_numbers__quota_order_number_id
                quota_order_numbers__quota_order_number_sid
                quota_order_numbers__validity_start_date
                quota_order_numbers__validity_end_date
              ],
            ).each do |quota_order_number|
            yield build_row_for(quota_order_number)
          end
        end
      end

      def build_row_for(quota_order_number)
        validity_start_date = quota_order_number[2]&.to_date&.strftime('%d/%m/%Y')
        validity_end_date = quota_order_number[3]&.to_date&.strftime('%d/%m/%Y')

        [
          quota_order_number[0],
          quota_order_number[1],
          validity_start_date,
          validity_end_date,
        ]
      end
    end
  end
end
