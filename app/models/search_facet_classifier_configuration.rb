class SearchFacetClassifierConfiguration
  CLASSIFIER_FILE_CLASSIFICATION_REGEX = %r{^classifier_(?<classifier>.*)\.json$}
  DEFAULT_CLASSIFIER_FILE_PATH = Rails.root.join('config/classifiers/*').freeze

  attr_accessor :word_classifications, :word_phrases, :facet_classifiers

  def self.build(word_classifications, word_phrases, facet_classifiers)
    configuration = new

    configuration.word_classifications = word_classifications
    configuration.word_phrases = word_phrases
    configuration.facet_classifiers = facet_classifiers

    configuration
  end

  def self.each_classification
    file_paths = Dir.glob(DEFAULT_CLASSIFIER_FILE_PATH)

    if block_given?
      file_paths.each do |file_path|
        classifier = File.basename(file_path).match(CLASSIFIER_FILE_CLASSIFICATION_REGEX)[:classifier]
        classification_words = JSON.parse(File.read(file_path))

        yield classifier, classification_words
      end
    end
  end
end
