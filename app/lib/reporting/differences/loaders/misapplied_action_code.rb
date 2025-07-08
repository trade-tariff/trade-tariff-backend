module Reporting
  class Differences
    class Loaders
      class MisappliedActionCode
        include Reporting::Differences::Loaders::Helpers

        private

        def data
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
              .dedupe_similar
              .with_regulation_dates_query
              .without_excluded_types
              .eager(
                measure_conditions: { measure_action: :measure_action_description },
                measure_type: :measure_type_description,
              )
              .association_inner_join(:measure_conditions)
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
end
