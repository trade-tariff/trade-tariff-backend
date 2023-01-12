module SpellingCorrector
  class FileUpdaterService
    LOADERS = [
      SpellingCorrector::Loaders::Initial,
      SpellingCorrector::Loaders::Synonyms,
      SpellingCorrector::Loaders::Descriptions,
      SpellingCorrector::Loaders::References,
      SpellingCorrector::Loaders::Intercepts,
      SpellingCorrector::Loaders::StopWords,
    ].freeze

    SPELLING_MODEL_PATH = 'spelling-corrector/spelling-model.txt'.freeze

    def call
      loaders = LOADERS.map { |loader| loader.new.tap(&:load) }
      spelling_model_content = spelling_model_content_for(loaders)

      bucket.put_object(key: SPELLING_MODEL_PATH, body: spelling_model_content_for(loaders))

      spelling_model_content
    end

    private

    def spelling_model_content_for(loaders)
      all_terms = loaders.each_with_object({}) do |loader, acc|
        acc.merge!(loader.terms) do |_term, original_count, additional_count|
          original_count + additional_count
        end
      end

      all_terms = all_terms.sort_by { |_term, count| -count }
      all_terms = all_terms.map { |term, count| "#{term} #{count}" }

      StringIO.new(all_terms.join("\n"))
    end

    def bucket
      Rails.application.config.spelling_corrector_s3_bucket
    end
  end
end
