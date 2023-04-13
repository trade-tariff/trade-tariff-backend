module Api
  module V2
    module Headings
      class SectionPresenter < SimpleDelegator
        def section_note
          super&.content
        end
      end
    end
  end
end
