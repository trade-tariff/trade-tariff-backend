module Reporting
  class Differences
    class MisappliedActionCode
      delegate :workbook,
               :regular_style,
               :bold_style,
               to: :report

      WORKSHEET_NAME = 'Misapplied action codes'.freeze

      HEADER_ROW = [
        'Measure sid',
        'Commodity code',
        'Measure type id',
        'Measure type description',
        'Geographical area id',
        'Measure condition sid',
        'Action code',
        'Measure action description',
        'Certificate code',
        'Component sequence number',
      ].freeze

      TAB_COLOR = '00ff00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze
      COLUMN_WIDTHS = Array.new(HEADER_ROW.size, 20).freeze

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

        each_missapplied_measure do |measure|
          measure.measure_conditions.each do |measure_condition|
            row = build_row_for(measure, measure_condition)

            acc << row unless row.nil?
          end
        end

        acc
      end

      def each_missapplied_measure(&block)
        TimeMachine.now do
          Measure
            .actual
            .dedupe_similar
            .with_regulation_dates_query
            .without_excluded_types
            .eager(
              measure_conditions: { measure_action: :measure_action_description },
              measure_type: :measure_type_description,
            )
            .association_join(:measure_conditions)
            .where(
              Sequel.lit(
                <<~SQL,
                  measure_conditions.action_code IN ('05', '06', '08', '09')
                    AND measure_conditions.certificate_type_code IS NOT NULL
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
          measure.goods_nomenclature_item_id,
          measure.measure_type_id,
          measure.measure_type.description,
          measure.geographical_area_id,
          measure_condition.measure_condition_sid,
          measure_condition.action_code,
          measure_condition.measure_action.description,
          "#{measure_condition.certificate_type_code}#{measure_condition.certificate_code}",
          measure_condition.component_sequence_number,
        ]
      end
    end
  end
end
