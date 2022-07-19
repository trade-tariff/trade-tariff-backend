module Api
  module Beta
    # Produces word classifications and word phrases which are used as part of the classification process.
    #   - word classifications are used to match words in a concatenated description tree to specific facet classifications
    #   - word phrases are used for exact match classifications when any ancestor description matches a given phrase
    #   - facet classifiers are all possible filters (with their states) we can apply in the search api for our given result set
    class ClassificationConverterService
      WHITESPACE_REGEX = /\s+/

      delegate :lemmatizer, to: TradeTariffBackend

      def initialize
        @word_classifications = {}
        @word_phrases = []
        @facet_classifiers = []
      end

      def call
        SearchFacetClassifierConfiguration.each_classification do |classifier, classification_words|
          @facet_classifiers << classifier

          classification_words.each do |classification_config|
            classification = classification_config.keys.first
            words = classification_config.values.flatten

            words.each do |word|
              @word_phrases << word if word.split(WHITESPACE_REGEX).many?

              lemma = lemmatizer.lemma(word)

              @word_classifications[word] ||= {}
              @word_classifications[word][classifier] = classification
              @word_classifications[lemma] ||= {}
              @word_classifications[lemma][classifier] = classification
            end
          end
        end

        SearchFacetClassifierConfiguration.build(
          @word_classifications,
          @word_phrases,
          @facet_classifiers,
        )
      end
    end
  end
end
