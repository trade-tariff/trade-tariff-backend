module SpellingCorrector
  module Loaders
    class Synonyms
      SYNONYMS_PATH = Rails.root.join('config/opensearch/synonyms_all.txt')

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
        Pathname.new(SYNONYMS_PATH).each_line do |line|
          terms = line.scan(/\w+/)

          terms.each do |term|
            normalised_term = SpellingCorrector::TermHandlerService.new(term).call

            yield normalised_term if normalised_term.present?
          end
        end
      end
    end
  end
end
