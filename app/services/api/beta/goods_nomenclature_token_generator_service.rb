module Api
  module Beta
    # Generates tokens which are classified later to indicate facet categories the current
    # goods nomenclature belongs too.
    #
    # This includes phrase tokens and word tokens that have been lemmatized and the stop words removed
    class GoodsNomenclatureTokenGeneratorService
      delegate :lemmatizer, :stop_words, to: TradeTariffBackend

      WHITESPACE = /\s+/

      def initialize(goods_nomenclature)
        @goods_nomenclature = goods_nomenclature
      end

      def call
        all_tokens = []
        candidate_description = @goods_nomenclature.description_indexed.downcase

        possible_phrases.each do |phrase|
          all_tokens << phrase if candidate_description.include?(phrase)
        end

        candidate_tokens = candidate_description.split(WHITESPACE)

        candidate_tokens.each do |candidate_token|
          candidate_token = candidate_token.gsub(/\W+/, '')

          next if invalid_token?(candidate_token)

          lemmatized_token = lemmatizer.lemma(candidate_token)

          all_tokens << lemmatized_token
        end

        all_tokens
      end

      private

      def invalid_token?(candidate_token)
        candidate_token.blank? || stop_words.include?(candidate_token)
      end

      def possible_phrases
        TradeTariffBackend.search_facet_classifier_configuration.word_phrases
      end
    end
  end
end
