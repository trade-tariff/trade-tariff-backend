module Api
  module V2
    module Headings
      class ChapterPresenter < SimpleDelegator
        def guide_ids
          guides.map(&:id)
        end
      end
    end
  end
end
