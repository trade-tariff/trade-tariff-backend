module Api
  module V2
    module Headings
      class ChapterPresenter < SimpleDelegator
        def chapter_note
          public_chapter_note&.content
        end
      end
    end
  end
end
