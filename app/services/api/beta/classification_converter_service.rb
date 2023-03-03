module Api
  module Beta
    # Produces word classifications and word phrases which are used as part of the classification process.
    #   - word classifications are used to match words in a concatenated description tree to specific facet classifications
    #   - word phrases are used for exact match classifications when any ancestor description matches a given phrase
    #   - facet classifiers are all possible filters (with their classifications) we can apply in the search api for our given result set
    #   - heading facet mappings enable us to filter facets to those which apply to specific headings
    class ClassificationConverterService
      WHITESPACE_REGEX = /\s+/

      delegate :lemmatizer, to: TradeTariffBackend

      def initialize
        @word_classifications = {}
        @word_phrases = []
        @facet_classifiers = {}
      end

      def call
        ::Beta::Search::SearchFacetClassifierConfiguration.each_classification do |classifier, classification_words|
          @facet_classifiers[classifier] = Set.new

          classification_words.each do |classification_config|
            classification = classification_config.keys.first
            @facet_classifiers[classifier] << classification
            words = classification_config.values.flatten

            words.each do |word|
              word = word.downcase

              @word_phrases << word if word.split(WHITESPACE_REGEX).many?

              lemma = lemmatizer.lemma(word)

              @word_classifications[word] ||= {}
              @word_classifications[word][classifier] = classification
              @word_classifications[lemma] ||= {}
              @word_classifications[lemma][classifier] = classification
            end
          end
        end

        ::Beta::Search::SearchFacetClassifierConfiguration.build(
          @word_classifications,
          @word_phrases,
          @facet_classifiers,
        )
      end
    end
  end
end

# *Labels*

# Labels are a way of associating a specific search term (e.g. "cotton") with a specific commodity

# This means that that commodity will be returned in the search results for that term

# These are managed via the admin interface and are stored in the backend database and extracted as part of a reindexing

# *Facets*

# Facets are filtering classifications that are automatically generated for the commodity tree by doing a reverse lookup for certain signficant terms on the joined hierarchy of descriptions and extracting the first applicable classification type for the given facet.

# *Search references*

# Search references are essentially pointers to specific goods nomenclature in the tree

# They are used in beta search in two ways:

# 1. When there is only one search reference we redirect the user to that goods nomenclature
# 2. When there are multiple search references they are used to return the applicable goods nomenclature that either directly have/inherit from the search referenced goods nomenclature

# *Intercept references*

# Intercept messages are used to provide a message to the user when they search for a specific term. They embed references to specific goods nomenclatures and these are extracted and used to provide more context for specific goods nomenclature in the search results.

# *Ancestor descriptions*

# Given we're searching through a taxonomy of goods nomenclature, we need to be able to search through the descriptions of the goods nomenclature and their ancestors. We forego querying the chapter descriptions since we've realised this is too general
