module Search
  module ExpansionDeciders
    class Base
      NOISE_TAGS = Search::GoodsNomenclatureQuery::NOISE_TAGS

      def self.call(query:, results:, max_score:)
        new(query:, results:, max_score:).call
      end

      def initialize(query:, results:, max_score:)
        @query = query.to_s
        @results = Array(results)
        @max_score = max_score
      end

      def call
        return 'no_significant_word_parts' if no_significant_word_parts?
        return 'low_result_count' if low_result_count?
        return 'low_max_score' if low_max_score?

        'sufficient_results'
      end

    private

      attr_reader :query, :results, :max_score

      def no_significant_word_parts?
        tagged_words = tag_words
        return false if tagged_words.empty?

        tagged_words.none? { |_word, tag| tag.present? && !NOISE_TAGS.include?(tag) }
      end

      def tag_words
        Search::GoodsNomenclatureQuery.tagger.get_readable(query).split.filter_map do |token|
          word, tag = token.split('/')
          next if word.blank? || word.match?(/\A\W+\z/)

          [word, tag&.downcase]
        end
      end

      def low_result_count?
        results.size < AdminConfiguration.integer_value('expand_search_min_results')
      end

      def low_max_score?
        return false if max_score.nil?

        max_score < AdminConfiguration.integer_value('expand_search_min_score')
      end
    end
  end
end
