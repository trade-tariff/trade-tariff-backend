module SpellingCorrector
  module Loaders
    class Intercepts
      def load
        each_term do |term|
          terms[term] += 1
        end

        terms
      end

      def terms
        @terms ||= Hash.new(0)
      end

      private

      def each_term
        intercept_terms.join(' ').scan(/\w+/).each do |term|
          normalised_term = SpellingCorrector::TermHandlerService.new(term).call

          yield normalised_term if normalised_term.present?
        end
      end

      def intercept_terms
        legacy_intercept_terms + description_intercept_terms
      end

      def legacy_intercept_terms
        Rails.application.config.intercept_messages.keys
      end

      def description_intercept_terms
        DescriptionIntercept.select_map(:term)
      end
    end
  end
end
