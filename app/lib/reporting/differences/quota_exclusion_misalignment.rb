module Reporting
  class Differences
    # Find UK measures and quotas which both have geographical area exclusions
    #
    # Checks to see if their exclusions are not aligned/the same
    class QuotaExclusionMisalignment
      delegate :workbook,
               :bold_style,
               :centered_style,
               :print_style,
               to: :report

      WORKSHEET_NAME = 'Exclusion misalignment'.freeze

      HEADER_ROW = [
        'Measure SID',
        'Order number',
        'Commodity',
        'Exclusions (quota, then measure)',
      ].freeze

      TAB_COLOR = 'cccc00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        20,  # "Measure SID"
        20,  # Order number
        20,  # Commodity
        150, # Exclusions (quota, then measure)
      ].freeze

      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(report)
        @report = report
      end

      def add_worksheet
        workbook.add_worksheet(name:) do |sheet|
          sheet.sheet_pr.tab_color = TAB_COLOR
          sheet.add_row(HEADER_ROW, style: bold_style)
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
            pane.state = :frozen
            pane.y_split = 1
          end

          misaligned_rows do |row|
            sheet.add_row(row, types: CELL_TYPES)

            sheet.rows.last.tap do |last_row|
              last_row.cells[1].style = centered_style
              last_row.cells[2].style = centered_style
              last_row.cells[3].style = print_style
            end
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      def name
        WORKSHEET_NAME
      end

      private

      attr_reader :report

      def misaligned_rows
        TimeMachine.at(report.as_of) do
          quota_order_numbers_grouped_by_key.each do |key, q|
            qm = measures_grouped_by_key[key]

            yield build_row_for(qm, q) if qm && (qm[:excluded_geographical_areas] != q[:excluded_geographical_areas])
          end
        end
      end

      def build_row_for(measure, quota_order_number)
        [
          measure[:measure_sid],
          quota_order_number[:quota_order_number],
          measure[:goods_nomenclature_item_id],
          "#{quota_order_number[:excluded_geographical_areas].join(',')}\n#{measure[:excluded_geographical_areas].join(',')}",
        ]
      end

      def quota_order_numbers_grouped_by_key
        quotas_with_excluded_geographical_areas.each_with_object({}) do |quota_order_number, acc|
          key = "#{quota_order_number.quota_order_number_id}-#{quota_order_number.quota_order_number_origin.geographical_area_id}"

          acc[key] ||= {
            measure_sid: quota_order_number.measure.measure_sid,
            goods_nomenclature_item_id: quota_order_number.measure.goods_nomenclature_item_id,
            quota_order_number: quota_order_number.quota_order_number_id,
            geographical_area_id: quota_order_number.quota_order_number_origin.geographical_area_id,
            excluded_geographical_areas: quota_order_number.quota_order_number_origin.quota_order_number_origin_exclusions.map(&:geographical_area_id).sort,
          }
        end
      end

      def measures_grouped_by_key
        @measures_grouped_by_key ||= quota_measures_with_excluded_geographical_areas
            .each_with_object({}) do |measure, acc|
              key = "#{measure.ordernumber}-#{measure.geographical_area_id}"
              acc[key] ||= {
                measure_sid: measure.measure_sid,
                goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
                quota_order_number: measure.ordernumber,
                geographical_area_id: measure.geographical_area_id,
                excluded_geographical_areas: measure.measure_excluded_geographical_areas.map(&:excluded_geographical_area).sort,
              }
            end
      end

      def quotas_with_excluded_geographical_areas
        @quotas_with_excluded_geographical_areas ||=
          QuotaOrderNumber
            .actual
            .eager(
              :measure,
              quota_order_number_origin: [{ quota_order_number_origin_exclusions: :geographical_area }],
            )
            .all
            .select do |quota_order_number|
              quota_order_number.quota_order_number_origin &&
                quota_order_number.measure
            end
      end

      def quota_measures_with_excluded_geographical_areas
        @quota_measures_with_excluded_geographical_areas ||=
          Measure
            .with_regulation_dates_query
            .exclude(ordernumber: nil)
            .exclude(ordernumber: /^0\d4/)
            .association_join(:quota_order_number)
            .eager(:measure_excluded_geographical_areas)
            .all
      end
    end
  end
end
