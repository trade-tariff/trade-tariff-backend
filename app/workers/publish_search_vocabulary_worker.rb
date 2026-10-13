# frozen_string_literal: true

# Bounded scheduled maintenance publisher for the search expansion
# vocabulary. It refreshes the generation for the current date of its own
# service. The next scheduled run retries a failed or skipped run; the
# previous complete generation stays readable throughout.
class PublishSearchVocabularyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  def perform
    result = Search::ExpansionVocabularyPublisher.call
    logger.info(
      "PublishSearchVocabularyWorker status=#{result.status} " \
      "generation=#{result.generation.inspect} word_count=#{result.word_count.inspect} " \
      "reason=#{result.reason.inspect}",
    )
    result
  end
end
