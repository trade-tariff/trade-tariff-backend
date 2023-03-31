module Api
  module V2
    module Subheadings
      class ChapterPresenter < SimpleDelegator
        def chapter_note
          super&.content
        end
      end
    end
  end
end
