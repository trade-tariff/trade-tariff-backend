module Reporting
  class Differences
    class Loaders
      class MfnMissing
        include Reporting::Differences::Loaders::Helpers

        delegate :each_chapter,
                 to: :report

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
          each_chapter(eager: Differences::GOODS_NOMENCLATURE_OVERVIEW_MEASURE_EAGER) do |eager_chapter|
            eager_chapter.descendants.each do |chapter_descendant|
              next unless chapter_descendant.declarable?

              next if chapter_descendant.applicable_overview_measures.any? do |measure|
                measure.measure_type_id.in?(MeasureType::THIRD_COUNTRY)
              end

              yield chapter_descendant
            end
          end
        end

        def build_row_for(declarable)
          [
            declarable.goods_nomenclature_item_id,
            declarable.description,
          ]
        end
      end
    end
  end
end
