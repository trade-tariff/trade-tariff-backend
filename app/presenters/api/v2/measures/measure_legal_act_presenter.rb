module Api
  module V2
    module Measures
      class MeasureLegalActPresenter < SimpleDelegator
        alias_method :regulation, :__getobj__

        def published_date
          regulation&.published_date
        end

        def regulation_code
          ApplicationHelper.regulation_code(regulation)
        end

        def regulation_url
          ApplicationHelper.regulation_url(regulation)
        end

        def description
          information_text
        end
      end
    end
  end
end
