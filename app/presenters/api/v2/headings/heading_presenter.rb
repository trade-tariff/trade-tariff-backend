module Api
  module V2
    module Headings
      class HeadingPresenter < SimpleDelegator
        delegate :id, to: :section, prefix: true

        def chapter_id
          chapter.goods_nomenclature_sid
        end

        def footnote_ids
          footnotes.map(&:footnote_id)
        end

        def section
          SectionPresenter.new(chapter.section)
        end

        def chapter
          @chapter ||= \
            ChapterPresenter.new(ns_ancestors.find { |a| a.is_a? Chapter })
        end

        def commodities
          @commodities ||= CommodityPresenter.wrap(ns_descendants)
        end

        def commodity_ids
          commodities.map(&:goods_nomenclature_sid)
        end
      end
    end
  end
end
