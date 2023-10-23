module Reporting
  class Differences
    class BadQuotaAssociation
      delegate :workbook,
               :regular_style,
               :bold_style,
               :centered_style,
               to: :report

      WORKSHEET_NAME = 'Self-referential associations'.freeze

      HEADER_ROW = [
        'Order number (main)',
        'Def. start date (main)',
        'Def. end date (main)',
        'Origin (main)',
        'Order number (sub)',
        'Def. start date (sub)',
        'Def. end date (sub)',
        'Origin (sub)',
        'Relation type',
        'Coefficient',
      ].freeze

      TAB_COLOR = 'cccc00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [20] * HEADER_ROW.size

      AUTOFILTER_CELL_RANGE = 'A1:J1'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(report)
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
            report.increment_count(name)
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      def name
        WORKSHEET_NAME
      end

      private

      attr_reader :report

      def each_row
        ::BadQuotaAssociation.actual.each do |bad_quota_association|
          yield build_row_for(bad_quota_association)
        end
      end

      def build_row_for(bad_quota_association)
        validity_start_date = bad_quota_association.validity_start_date.strftime('%d/%m/%Y')
        validity_end_date = bad_quota_association.validity_end_date.strftime('%d/%m/%Y')
        [
          bad_quota_association.main_quota_order_number_id,
          validity_start_date,
          validity_end_date,
          bad_quota_association.main_origin,
          bad_quota_association.sub_quota_order_number_id,
          validity_start_date,
          validity_end_date,
          bad_quota_association.sub_origin,
          bad_quota_association.relation_type,
          bad_quota_association.coefficient,
        ]
      end
    end
  end
end
