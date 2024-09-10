module Reporting
  class Differences
    class Loaders
      class SupplementaryUnit
        include Reporting::Differences::Loaders::Helpers

        delegate                  :uk_supplementary_unit_measures,
                                  :xi_supplementary_unit_measures, to: :report

        def initialize(source, target, report)
          @source = source
          @target = target
          @report = report
        end

        private

        attr_reader :source, :target, :report

        def data
          all_missing = source_measures - target_measures
          all_missing.map(&:to_row)
        end

        def target_measures
          @target_measures ||= PresentedSupplementaryUnitMeasure.wrap(
            public_send("#{target}_supplementary_unit_measures"),
          )
        end

        def source_measures
          @source_measures ||= PresentedSupplementaryUnitMeasure.wrap(
            public_send("#{source}_supplementary_unit_measures"),
          )
        end
      end

      class PresentedSupplementaryUnitMeasure < WrapDelegator
        def initialize(measure)
          @measure = measure
          super
        end

        def to_row
          [
            commodity_code,
            geographical_area_id,
            measure_type_id,
            measurement_unit_code,
            measurement_unit_qualifier_code,
          ]
        end

        def eql?(other)
          to_row.eql?(other.to_row)
        end

        delegate :hash, to: :to_row

        private

        attr_reader :measure

        def commodity_code
          measure['goods_nomenclature_item_id']
        end

        def geographical_area_id
          measure['geographical_area_id']
        end

        def measure_type_id
          measure['measure_type_id']
        end

        def measurement_unit_code
          measure['measurement_unit_code']
        end

        def measurement_unit_qualifier_code
          measure['measurement_unit_qualifier_code']
        end
      end
    end
  end
end
