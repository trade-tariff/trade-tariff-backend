module SpellingCorrector
  module Loaders
    class Descriptions
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
        GoodsNomenclature.actual.eager(:goods_nomenclature_descriptions).each do |goods_nomenclature|
          goods_nomenclature.description.scan(/\w+/).map do |term|
            normalised_term = SpellingCorrector::TermHandlerService.new(term).call

            yield normalised_term if normalised_term.present?
          end
        end
      end
    end
  end
end
