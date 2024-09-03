module Reporting
  class Differences
    class Loaders
      class Me32
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
            counts = Hash.new(0)

            PresentedMeasure.wrap(declarable.applicable_measures).each do |measure|
              counts[measure] += 1
            end

            counts.each do |measure, count|
              next if count == 1

              yield declarable, measure
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
            measure.measure_type_id,
            measure.additional_code,
            measure.ordernumber,
            measure.geographical_area_id,
          ]
        end

        class PresentedMeasure < WrapDelegator
          def hash
            [
              measure_type_id,
              additional_code,
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
              additional_code == other.additional_code &&
              ordernumber == other.ordernumber &&
              geographical_area_id == other.geographical_area_id
          end

          def additional_code
            "#{additional_code_type_id}#{additional_code_id}".presence || nil
          end
        end
      end
    end
  end
end
