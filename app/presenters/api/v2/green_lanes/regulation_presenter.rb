module Api
  module V2
    module GreenLanes
      class RegulationPresenter < WrapDelegator
        def initialize(regulation)
          super
          @regulation = regulation
        end

        def published_date
          @regulation.try(:published_date)
        end

        def regulation_code
          ApplicationHelper.regulation_code(@regulation)
        end

        def regulation_url
          ApplicationHelper.regulation_url(@regulation)
        end

        def description
          @regulation.try(:information_text)
        end
      end
    end
  end
end
