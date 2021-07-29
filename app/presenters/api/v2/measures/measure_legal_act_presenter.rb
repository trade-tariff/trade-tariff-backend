module Api
  module V2
    module Measures
      class MeasureLegalActPresenter < SimpleDelegator
        alias_method :regulation, :__getobj__

        EXCLUDED_REGULATION_IDS = %w[IYY99990].freeze

        def published_date
          regulation&.published_date
        end

        def regulation_code
          show_full_info? ? ApplicationHelper.regulation_code(regulation) : ''
        end

        def regulation_url
          show_full_info? ? ApplicationHelper.regulation_url(regulation) : ''
        end

        def description
          show_full_info? ? information_text : nil
        end

      private

        def show_full_info?
          !excluded_regulation?
        end

        def excluded_regulation?
          EXCLUDED_REGULATION_IDS.include? regulation.regulation_id
        end
      end
    end
  end
end
