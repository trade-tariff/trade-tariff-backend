module Api
  module V2
    module Chapters
      class ChapterPresenter < SimpleDelegator
        def initialize(chapter, all_headings)
          @all_headings = all_headings
          super(chapter)
        end

        def heading_ids
          headings.map(&:goods_nomenclature_sid)
        end

        def headings
          @headings ||= HeadingPresenter.wrap(@all_headings)
        end
      end
    end
  end
end
