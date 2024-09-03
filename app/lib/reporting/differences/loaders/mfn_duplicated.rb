module Reporting
  class Differences
    class Loaders
      class MfnDuplicated
        delegate :each_chapter, to: :report

        include Reporting::Differences::Loaders::Helpers

        private

        def data
          acc = []

          each_declarable do |declarable|
            row = build_row_for(declarable)

            acc << row unless row.nil?
          end

          acc
        end

        def each_declarable
          each_chapter(eager: Differences::GOODS_NOMENCLATURE_OVERVIEW_MEASURE_WITH_COMPONENTS_EAGER) do |eager_chapter|
            eager_chapter.descendants.each do |chapter_descendant|
              next unless chapter_descendant.declarable?

              candidate_mfns = chapter_descendant.applicable_overview_measures.select do |measure|
                measure.measure_type_id.in?(MeasureType::THIRD_COUNTRY)
              end

              # TODO: ME16 violations (mixture of additional code and
              #      non-additional code measures of the same type) are acceptable
              #      for the present moment.
              #
              #      This is because these aren't going to get fixed in the short term.
              any_additional_code_measures = candidate_mfns.any?(&:additional_code_sid)
              all_different_type_measures = candidate_mfns.map(&:measure_type_id).uniq.size == 2 && candidate_mfns.size == 2

              next if any_additional_code_measures || all_different_type_measures

              yield chapter_descendant if candidate_mfns.many?
            end
          end
        end

        def build_row_for(declarable)
          mfn_measures = declarable.applicable_overview_measures.select do |measure|
            measure.measure_type_id.in?(MeasureType::THIRD_COUNTRY)
          end

          mfn_measure_1 = mfn_measures.first
          mfn_measure_2 = mfn_measures.second

          [
            declarable.goods_nomenclature_item_id,
            declarable.description,
            mfn_measure_1.measure_sid,
            "#{mfn_measure_1.additional_code_type_id}#{mfn_measure_1.additional_code_id}",
            mfn_measure_1.duty_expression,
            mfn_measure_1.measure_type_id,
            mfn_measure_2.measure_sid,
            "#{mfn_measure_2.additional_code_type_id}#{mfn_measure_2.additional_code_id}",
            mfn_measure_2.duty_expression,
            mfn_measure_2.measure_type_id,
          ]
        end
      end
    end
  end
end
