module Api
  module V2
    module Headings
      class SectionPresenter < SimpleDelegator
        def section_note
          public_section_note&.content
        end
      end
    end
  end
end
