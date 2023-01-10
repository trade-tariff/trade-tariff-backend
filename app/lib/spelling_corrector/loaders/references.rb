module SpellingCorrector
  module Loaders
    class References
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
        SearchReference.pluck(:title).join(' ').scan(/\w+/).map do |term|
          normalised_term = SpellingCorrector::TermHandlerService.new(term).call

          yield normalised_term if normalised_term.present?
        end
      end
    end
  end
end
