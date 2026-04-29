module SpellingCorrector
  module Loaders
    class Initial
      INITIAL_SPELLING_MODEL_PATH = 'spelling-corrector/initial-spelling-model.txt'.freeze

      def load
        each_term do |line|
          term, count = line.split(' ')
          normalised_term = SpellingCorrector::TermHandlerService.new(term).call
          terms[normalised_term] = count.to_i if normalised_term.present?
        end

        terms
      end

      def terms
        @terms ||= Hash.new(0)
      end

      private

      def each_term(&block)
        bucket.object(INITIAL_SPELLING_MODEL_PATH).get.body.each_line(&block)
      end

      def bucket
        Rails.application.config.spelling_corrector_s3_bucket
      end
    end
  end
end
