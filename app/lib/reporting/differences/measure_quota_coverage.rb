module Reporting
  class Differences
    # Find all measures that have quota definitions
    #
    # Checks to see if there is at least one definition within each measures validity window
    class MeasureQuotaCoverage
      delegate :workbook, :bold_style, :regular_style, to: :report

      WORKSHEET_NAME = 'Measure quot def coverage'.freeze

      HEADER_ROW = [
        'Measure SID',
        'Commodity code',
        'Quota order number ID',
        'Geographical area',
        'Measure extent',
        'Quota definition extent',
      ].freeze

      TAB_COLOR = 'cccc00'.freeze
      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze
      COLUMN_WIDTHS = [20] * HEADER_ROW.size
      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(report)
        @report = report
        @end_of_year = Time.zone.today.end_of_year
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

          rows.each do |row|
            report.increment_count(name)
            sheet.add_row(
              row,
              types: CELL_TYPES,
              style: regular_style,
            )
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      def name
        WORKSHEET_NAME
      end

      private

      attr_reader :report

      def rows
        rs = measures_with_quota_definitions.each_with_object([]) do |measure_with_quota_definitions, acc|
          measure = measure_with_quota_definitions[:measure]
          quota_definitions = measure_with_quota_definitions[:quota_definitions]
          has_quota_definition = false
          quota_definition_dates = []

          quota_definitions.each do |quota_definition|
            m_start = measure.effective_start_date
            m_end = measure.effective_end_date.presence || @end_of_year
            q_start = quota_definition.validity_start_date
            q_end = quota_definition.validity_end_date

            within_measure = m_start <= q_start && m_end >= q_end
            within_measure ||= q_end >= @end_of_year

            quota_definition_dates << [quota_definition.validity_start_date, quota_definition.validity_end_date]

            next unless within_measure

            has_quota_definition = true

            break
          end

          unless has_quota_definition
            acc << build_row_for(measure, quota_definition_dates)
          end
        end

        rs.sort_by do |row|
          [
            row[2], # ordernumber
            row[1], # goods_nomenclature_item_id
          ]
        end
      end

      def build_row_for(measure, quota_definition_dates)
        quota_definition_dates = quota_definition_dates.map { |start_date, end_date|
          start_date = start_date.to_date.to_fs(:govuk_short_approx)
          end_date = end_date.to_date.to_fs(:govuk_short_approx) if end_date.present?
          end_date = (end_date.presence || '-')

          [start_date, end_date].join(' - ')
        }.join("\n")

        measure_start_date = measure.effective_start_date.to_date.to_fs(:govuk_short_approx)
        measure_end_date = measure.effective_end_date.to_date.to_fs(:govuk_short_approx) if measure.effective_end_date.present?
        measure_end_date = (measure_end_date.presence || '-')
        measure_extent = [measure_start_date, measure_end_date].join(' - ')

        [
          measure.measure_sid,
          measure.goods_nomenclature_item_id,
          measure.ordernumber,
          measure.geographical_area_id,
          measure_extent,
          quota_definition_dates,
        ]
      end

      def measures_with_quota_definitions
        applicable_measures.map do |measure|
          {
            measure:,
            quota_definitions: applicable_quota_definitions.select do |quota_definition|
                                 measure.ordernumber == quota_definition.quota_order_number_id
                               end,
          }
        end
      end

      def applicable_measures
        @applicable_measures ||= Measure
            .with_regulation_dates_query_non_current
            .since_brexit
            .excluding_licensed_quotas
            .exclude(ordernumber: nil)
            .all
      end

      def applicable_quota_definitions
        @applicable_quota_definitions ||= QuotaDefinition
          .where(quota_order_number_id: applicable_measures.pluck(:ordernumber))
          .excluding_licensed_quotas
          .since_brexit
          .all
      end
    end
  end
end
