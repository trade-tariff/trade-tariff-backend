module Reporting
  class Differences
    class Loaders
      class QuotaExclusionMisalignment
        include Reporting::Differences::Loaders::Helpers

        # Find UK measures and quotas which both have geographical area exclusions
        #
        # Checks to see if their exclusions are not aligned/the same
        #
        #
        def data
          rows = []
          misaligned_rows do |row|
            rows << row
          end
          rows
        end

        private

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
              .association_inner_join(:quota_order_number)
              .eager(:measure_excluded_geographical_areas)
              .all
        end
      end
    end
  end
end
