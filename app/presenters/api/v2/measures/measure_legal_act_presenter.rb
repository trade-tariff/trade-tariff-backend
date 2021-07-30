module Api
  module V2
    module Measures
      class MeasureLegalActPresenter < SimpleDelegator
        alias_method :regulation, :__getobj__
        delegate :uk?, to: TradeTariffBackend
        delegate :regulation_url, :regulation_code, :description,
                 to: :uk_regulation, prefix: :uk

        EXCLUDED_REGULATION_IDS = %w[IYY99990].freeze

        def published_date
          regulation&.published_date
        end

        def regulation_code
          return '' if show_reduced_info?

          uk? ? uk_regulation_code : xi_regulation_code
        end

        def regulation_url
          return '' if show_reduced_info?

          uk? ? uk_regulation_url : xi_regulation_url
        end

        def description
          return nil if show_reduced_info?

          uk? ? uk_description : information_text
        end

      private

        def show_reduced_info?
          excluded_regulation?
        end

        def excluded_regulation?
          EXCLUDED_REGULATION_IDS.include? regulation.regulation_id
        end

        def xi_regulation_code
          ApplicationHelper.regulation_code(regulation)
        end

        def xi_regulation_url
          ApplicationHelper.regulation_url(regulation)
        end

        def uk_regulation
          @uk_regulation ||= UkRegulationParser.new(regulation.information_text)
        end
      end
    end
  end
end
