module Api
  module V2
    module Chapters
      class ChapterPresenter < SimpleDelegator
        def heading_ids
          headings.map(&:goods_nomenclature_sid)
        end

        def headings
          @headings ||= HeadingPresenter.wrap(ns_children)
        end
      end
    end
  end
end
