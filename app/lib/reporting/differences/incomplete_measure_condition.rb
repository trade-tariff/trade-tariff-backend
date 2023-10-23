module Reporting
  class Differences
    class IncompleteMeasureCondition
      delegate :workbook,
               :regular_style,
               :bold_style,
               to: :report

      WORKSHEET_NAME = 'Incomplete conditions'.freeze

      DASHBOARD_SECTION = 'Duty and measure-related anomalies'.freeze

      HEADER_ROW = [
        'Measure SID',
        'Measure type ID',
        'Start date',
        'Commodity',
        'Geographical area',
        'Condition duty amount',
        'Action code',
        'Action',
      ].freeze

      TAB_COLOR = '00ff00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze
      COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 20).freeze

      AUTOFILTER_CELL_RANGE = 'A1:H1'.freeze
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

          rows.compact.each do |row|
            report.increment_count(name)
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      def name
        WORKSHEET_NAME
      end

      private

      attr_reader :report

      def rows
        acc = []

        each_incomplete_measure do |measure|
          measure.measure_conditions.each do |measure_condition|
            row = build_row_for(measure, measure_condition)

            acc << row unless row.nil?
          end
        end

        acc
      end

      def each_incomplete_measure(&block)
        TimeMachine.now do
          Measure
            .actual
            .dedupe_similar
            .with_regulation_dates_query
            .without_excluded_types
            .eager(
              [
                :measure_type,
                { measure_conditions: { measure_action: :measure_action_description } },
              ],
            )
            .association_join(:measure_conditions)
            .where(
              Sequel.lit(
                <<~SQL,
                  measure_conditions.action_code > '10'
                    AND measure_conditions.certificate_type_code IS NULL
                    AND measure_conditions.condition_measurement_unit_code IS NULL
                    AND measure_conditions.condition_monetary_unit_code IS NULL
                    AND measure_conditions.condition_duty_amount IS NOT NULL
                SQL
              ),
            )
            .all
            .each(&block)
        end
      end

      def build_row_for(measure, measure_condition)
        [
          measure.measure_sid,
          measure.measure_type_id,
          measure.effective_start_date.to_date.strftime('%d/%m/%Y'),
          measure.goods_nomenclature_item_id,
          measure.geographical_area_id,
          measure_condition.condition_duty_amount,
          measure_condition.action_code,
          measure_condition.measure_action.description,
        ]
      end
    end
  end
end
