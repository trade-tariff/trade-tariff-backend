module Reporting
  class Differences
    class Loaders
      class CandidateSupplementaryUnit
        include Reporting::Differences::Loaders::Helpers

        delegate :each_chapter,
                 to: :report

        IGNORED_UNITS = %w[ASVX SPQ ASV SPQLTR SPQLPA].freeze

        def data
          rows = []
          each_row do |row|
            rows << row
          end
          rows
        end

        private

        def each_row
          each_declarable do |declarable|
            units = candidate_units_for(declarable)
            unit_codes = units.map do |unit|
              "#{unit[:measurement_unit_code]}#{unit[:measurement_unit_qualifier_code]}"
            end

            next unless units.any?

            yield [
              declarable.goods_nomenclature_item_id,
              unit_codes.uniq.sort.join(', '),
            ]
          end
        end

        # There are three rules for when a unit that is associated with a measure
        # (and therefore a commodity) could potentially be a supplementary unit that
        # should be declared:
        #
        # 1. The commodity has no supplementary units associated with it and there are units
        #    associated with the commodities measures.
        # 2. The commodity has supplementary units associated with it and there are units
        #    of a different class/or type.
        # 3. We have specific heuristics/business rules that tell us that a unit should be ignored
        def candidate_units_for(declarable)
          supplementary_unit_measures = declarable.applicable_measures.select(&:supplementary?)
          relevant_measures = declarable.applicable_measures - supplementary_unit_measures
          units = relevant_measures.flat_map(&:units)

          if supplementary_unit_measures.any?
            supplementary_unit_types = supplementary_unit_types_for(supplementary_unit_measures)

            units.reject do |unit|
              type = MeasurementUnit.type_for(
                "#{unit[:measurement_unit_code]}#{unit[:measurement_unit_qualifier_code]}",
              )

              supplementary_unit_types.include?(type) || ignore_unit?(unit)
            end
          else
            units.reject(&method(:ignore_unit?))
          end
        end

        def each_declarable
          each_chapter(eager: Differences::GOODS_NOMENCLATURE_MEASURE_WITH_UNIT_EAGER) do |eager_chapter|
            eager_chapter.descendants.each do |chapter_descendant|
              yield chapter_descendant if chapter_descendant.declarable?
            end
          end
        end

        def supplementary_unit_types_for(supplementary_unit_measures)
          supplementary_unit_measures
            .flat_map(&:units)
            .map do |unit|
              full_unit = "#{unit[:measurement_unit_code]}#{unit[:measurement_unit_qualifier_code]}"

              MeasurementUnit.type_for(full_unit)
            end
        end

        def ignore_unit?(unit)
          full_unit = "#{unit[:measurement_unit_code]}#{unit[:measurement_unit_qualifier_code]}"

          MeasurementUnit.coerced_unit_for(full_unit) == 'KGM' || IGNORED_UNITS.include?(full_unit)
        end
      end
    end
  end
end
