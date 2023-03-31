module Api
  module V2
    module Headings
      class HeadingPresenter < SimpleDelegator
        def chapter_id
          chapter.goods_nomenclature_sid
        end

        def footnote_ids
          footnotes.map(&:footnote_id)
        end

        def section
          SectionPresenter.new(super)
        end

        def chapter
          ChapterPresenter.new(super)
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
