module Api
  module Beta
    class GoodsNomenclatureTokenGeneratorService
      delegate :lemmatizer, :stop_words, to: :class

      STOP_WORDS_FILE = Rails.root.join('db/beta/search/stop_words.yml')
      WHITESPACE = /\s+/

      def initialize(goods_nomenclatures)
        @goods_nomenclatures = goods_nomenclatures
      end

      def call
        TimeMachine.now(&method(:enumerate_tokens))
      end

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

      def self.lemmatizer
        @lemmatizer ||= Lemmatizer.new
      end

      def self.stop_words
        @stop_words ||= YAML.load_file(STOP_WORDS_FILE)[:stop_words]
      end
    end
  end
end
