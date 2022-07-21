module Api
  module Beta
    # Generates tokens which are classified later to indicate facet categories the current
    # goods nomenclature belongs too.
    #
    # The input goods nomenclatures include the initial goods nomenclature and its ancestors.
    # The result is reversed because we accumulate classifications later and the lowest ancestor
    # description needs to set the facet classification to be more price. This is especially true where chapters, headings and subheadings may have multiple classifications for a given facet.
    class GoodsNomenclatureTokenGeneratorService
      delegate :lemmatizer, :stop_words, to: TradeTariffBackend

      WHITESPACE = /\s+/

      def initialize(goods_nomenclatures)
        @goods_nomenclatures = goods_nomenclatures
      end

      def call
        TimeMachine.now(&method(:enumerate_tokens))
      end

      private

      def enumerate_tokens
        all_tokens = @goods_nomenclatures.each_with_object([]) do |ancestor, tokens|
          ancestor.description_indexed.split(WHITESPACE).each do |candidate_token|
            original_token = candidate_token
            candidate_token = candidate_token.downcase
            candidate_token = candidate_token.gsub(/\W+/, '')

            next if candidate_token.blank?
            next if stop_words.include?(candidate_token)

            analysed_token = lemmatizer.lemma(candidate_token)

            tokens << { analysed_token:, original_token: }
          end
        end

        all_tokens.reverse
      end
    end
  end
end
