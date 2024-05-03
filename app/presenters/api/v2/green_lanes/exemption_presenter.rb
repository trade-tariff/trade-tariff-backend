module Api
  module V2
    module GreenLanes
      class ExemptionPresenter < WrapDelegator
        def id
          code
        end

        def formatted_description
          description
        end
      end
    end
  end
end
