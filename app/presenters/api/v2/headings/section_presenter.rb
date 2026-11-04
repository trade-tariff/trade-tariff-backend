module Api
  module V2
    module Headings
      class SectionPresenter < SimpleDelegator
        def section_note
          customs_tariff_section_note&.content
        end
      end
    end
  end
end
