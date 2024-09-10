module Reporting
  class Differences
    class Loaders
      class Me16
        include Reporting::Differences::Loaders::Helpers

        delegate :each_chapter,
                 to: :report

        private

        def data
          acc = []

          each_declarable_and_measure do |declarable, measure|
            row = build_row_for(declarable, measure)

            acc << row unless row.nil?
          end

          acc
        end

        def each_declarable_and_measure
          each_declarable do |declarable|
            measures = {}

            PresentedMeasure.wrap(declarable.applicable_measures).each do |measure|
              measures[measure] ||= []
              measures[measure] << measure
            end

            measures.each do |measure, ms|
              next if measure.vat?

              additional_code_measures = ms.select(&:additional_code)
              no_additional_code_measures = ms.reject(&:additional_code)

              yield declarable, measure if additional_code_measures.any? && no_additional_code_measures.any?
            end
          end
        end

        def each_declarable
          each_chapter(eager: Differences::GOODS_NOMENCLATURE_MEASURE_EAGER) do |eager_chapter|
            eager_chapter.descendants.each do |chapter_descendant|
              next unless chapter_descendant.declarable?

              yield chapter_descendant
            end
          end
        end

        def build_row_for(declarable, measure)
          [
            declarable.goods_nomenclature_item_id,
            measure.measure_type_description,
          ]
        end

        class PresentedMeasure < WrapDelegator
          def hash
            [
              measure_type_id,
              ordernumber,
              geographical_area_id,
            ].hash
          end

          # Used as a secondary check (primary being the #hash method)
          # when comparing measures in an accumulating hash.
          #
          # This enables us to pick out duplicate measures based on a custom
          # definition of equality.
          def eql?(other)
            measure_type_id == other.measure_type_id &&
              ordernumber == other.ordernumber &&
              geographical_area_id == other.geographical_area_id
          end

          def additional_code
            "#{additional_code_type_id}#{additional_code_id}".presence || nil
          end

          def measure_type_description
            PresentedMeasure.measure_type_descriptions[measure_type_id]
          end

          def vat?
            measure_type_id.in? MeasureType::VAT_TYPES
          end

          def self.measure_type_descriptions
            @measure_type_descriptions ||= MeasureTypeDescription.all.index_by(&:measure_type_id)
          end
        end
      end
    end
  end
end
