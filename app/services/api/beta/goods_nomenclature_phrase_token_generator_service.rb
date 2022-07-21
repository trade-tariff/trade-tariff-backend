module Api
  module Beta
    class GoodsNomenclaturePhraseTokenGeneratorService
      def initialize(goods_nomenclatures)
        @goods_nomenclatures = goods_nomenclatures
      end

      def call
        TimeMachine.now(&method(:enumerate_tokens))
      end

      private

      def enumerate_tokens
        all_tokens = @goods_nomenclatures.each_with_object([]) do |ancestor, tokens|
          description = ancestor.description_indexed.downcase

          phrases.each do |phrase|
            tokens << phrase if description.include?(phrase)
          end
        end

        all_tokens.reverse
      end

      def phrases
        TradeTariffBackend.search_facet_classifier_configuration.word_phrases
      end
    end
  end
end
