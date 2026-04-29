module SpellingCorrector
  module Loaders
    class Labels
      LABEL_FIELDS = %i[description known_brands colloquial_terms synonyms].freeze

      def load
        TimeMachine.now do
          each_term do |term|
            terms[term] += 1
          end
        end

        terms
      end

      def terms
        @terms ||= Hash.new(0)
      end

      private

      def each_term
        GoodsNomenclatureLabel.exclude(expired: true).each do |label|
          label_terms(label).join(' ').scan(/\w+/) do |term|
            normalised_term = SpellingCorrector::TermHandlerService.new(term).call

            yield normalised_term if normalised_term.present?
          end
        end
      end

      def label_terms(label)
        LABEL_FIELDS.flat_map { |field| Array(label.public_send(field)) }.compact
      end
    end
  end
end
