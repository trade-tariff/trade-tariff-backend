module Api
  module V2
    module Subheadings
      class SectionPresenter < SimpleDelegator
        def section_note
          super&.content
        end
      end
    end
  end
end
