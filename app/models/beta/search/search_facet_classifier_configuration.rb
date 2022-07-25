require 'csv'

module Beta
  module Search
    class SearchFacetClassifierConfiguration
      CLASSIFIER_FILE_CLASSIFICATION_REGEX = %r{^classifier_(?<classifier>.*)\.json$}
      CLASSIFIER_FILE_PATH = Rails.root.join('config/classifiers/*').freeze
      HEADING_MAPPINGS_FILE_PATH = Rails.root.join('db/heading_facet_mappings.csv').freeze

      HEADING_CODE_FIELD_NAME = 'Category'.freeze

      attr_accessor :word_classifications,
                    :word_phrases,
                    :facet_classifiers,
                    :heading_facet_mappings

      def serializable_classifications
        facet_classifiers.keys.sort
      end

      def self.build(word_classifications, word_phrases, facet_classifiers)
        configuration = new

        configuration.word_classifications = word_classifications
        configuration.word_phrases = word_phrases
        configuration.facet_classifiers = facet_classifiers
        configuration.heading_facet_mappings = heading_facet_mappings

        configuration
      end

      def self.each_classification
        file_paths = Dir.glob(CLASSIFIER_FILE_PATH)

        if block_given?
          file_paths.each do |file_path|
            classifier = File.basename(file_path).match(CLASSIFIER_FILE_CLASSIFICATION_REGEX)[:classifier]
            classification_words = JSON.parse(File.read(file_path))

            yield classifier, classification_words
          end
        end
      end

      def self.heading_facet_mappings
        mappings = {}

        CSV.open(HEADING_MAPPINGS_FILE_PATH, 'rb', headers: true) do |rows|
          rows.each do |row|
            mappings[row[HEADING_CODE_FIELD_NAME]] = row[2..].compact
          end
        end

        mappings
      end
    end
  end
end
