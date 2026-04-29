module SpellingCorrector
  module Loaders
    class SelfTexts
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
        GoodsNomenclatureSelfText
          .exclude(expired: true)
          .exclude(self_text: nil)
          .select_map(:self_text)
          .join(' ')
          .scan(/\w+/) do |term|
            normalised_term = SpellingCorrector::TermHandlerService.new(term).call

            yield normalised_term if normalised_term.present?
          end
      end
    end
  end
end
