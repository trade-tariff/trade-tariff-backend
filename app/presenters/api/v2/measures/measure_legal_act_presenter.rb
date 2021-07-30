module Api
  module V2
    module Measures
      class MeasureLegalActPresenter < SimpleDelegator
        alias_method :regulation, :__getobj__
        delegate :regulation_url, :regulation_code, :description,
                 to: :uk_regulation_data, prefix: :uk

        EXCLUDED_REGULATION_IDS = %w[IYY99990].freeze

        def published_date
          regulation&.published_date
        end

        def regulation_code
          return '' if show_reduced_info?

          uk? ? uk_regulation_code : eu_regulation_code
        end

        def regulation_url
          return '' if show_reduced_info?

          uk? ? uk_regulation_url : eu_regulation_url
        end

        def description
          return nil if show_reduced_info?

          uk? ? uk_description : information_text
        end

      private

        def uk?
          TradeTariffBackend.uk? &&
            regulation.officialjournal_number == "1" &&
            regulation.officialjournal_page == 1
        end

        def show_reduced_info?
          excluded_regulation?
        end

        def excluded_regulation?
          EXCLUDED_REGULATION_IDS.include? regulation.regulation_id
        end

        def eu_regulation_code
          ApplicationHelper.regulation_code(regulation)
        end

        def eu_regulation_url
          ApplicationHelper.regulation_url(regulation)
        end

        def uk_regulation_data
          @uk_regulation_data ||= UkRegulationParser.new(regulation.information_text)
        end
      end
    end
  end
end
