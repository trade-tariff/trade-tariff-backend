module Api
  module V2
    module GreenLanes
      class MeasurePresenter < WrapDelegator
        def footnote_ids
          @footnote_ids = footnotes.map(&:code)
        end
      end
    end
  end
end
