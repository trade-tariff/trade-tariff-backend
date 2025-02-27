module Reporting
  class Differences
    class Loaders
      class MissingVatMeasure
        include Reporting::Differences::Loaders::Helpers

        FILTERED_MEASURE_TYPES = Set.new(%w[305]).freeze

        delegate :each_chapter,
                 to: :report

        attr_reader :report

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
            row = build_row_for(declarable)

            yield row if row.present?
          end
        end

        def each_declarable
          each_chapter(eager: Differences::GOODS_NOMENCLATURE_OVERVIEW_MEASURE_EAGER) do |eager_chapter|
            eager_chapter.descendants.each do |chapter_descendant|
              next unless chapter_descendant.declarable?
              next if chapter_descendant.classified?

              next if chapter_descendant.applicable_overview_measures.find { |measure|
                measure.measure_type_id.in?(FILTERED_MEASURE_TYPES)
              }.present?

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
