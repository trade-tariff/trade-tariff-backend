module Api
  module V2
    module Headings
      class ChapterPresenter < SimpleDelegator
        def chapter_note
          customs_tariff_chapter_note&.content
        end
      end
    end
  end
end
