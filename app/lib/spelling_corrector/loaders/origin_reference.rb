module SpellingCorrector
  module Loaders
    class OriginReference
      ORIGIN_REFERENCE_OBJECTS_PREFIX_PATH = 'spelling-corrector/origin-reference/'.freeze

      def load
        each_term do |term|
          terms[term] += 1
        end

        terms
      end

      def terms
        @terms ||= Hash.new(0)
      end

      private

      def each_term
        each_file do |io|
          io.each_line do |line|
            line.scan(/\w+/).map do |term|
              normalised_term = SpellingCorrector::TermHandlerService.new(term).call

              yield normalised_term if normalised_term.present?
            end
          end
        end
      end

      def each_file
        object_summaries.each do |object_summary|
          yield object_summary.get.body
        end
      end

      def object_summaries
        bucket.objects(prefix: ORIGIN_REFERENCE_OBJECTS_PREFIX_PATH)
      end

      def bucket
        Rails.application.config.spelling_corrector_s3_bucket
      end
    end
  end
end
