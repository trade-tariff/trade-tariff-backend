module Reporting
  class Differences
    class Loaders
      class IncompleteMeasureCondition
        include Reporting::Differences::Loaders::Helpers

        private

        def data
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
              .association_inner_join(:measure_conditions)
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
end
