require_relative '../lib/self_text_generator/instrumentation'
require_relative '../lib/self_text_generator/logger'

class GenerateSelfTextChapterWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: 2, slack_alerts: false

  sidekiq_retries_exhausted do |_job, _exception|
    remaining = TradeTariffBackend.redis.decr(GenerateSelfTextWorker::REDIS_KEY)
    if remaining <= 0
      SelfTextGenerator::Instrumentation.generation_completed
      GenerateSelfTextReindexWorker.perform_async
    end
  end

  def perform(chapter_sid)
    chapter = TimeMachine.now do
      Chapter.actual
        .where(goods_nomenclature_sid: chapter_sid)
        .eager(:goods_nomenclature_descriptions)
        .first
    end
    return unless chapter

    chapter_code = chapter.short_code

    SelfTextGenerator::Instrumentation.chapter_started(
      chapter_sid:,
      chapter_code:,
    )

    SelfTextGenerator::Instrumentation.chapter_completed(chapter_sid:, chapter_code:) do |payload|
      mechanical_stats = GenerateSelfText::MechanicalBuilder.call(chapter)
      ai_stats = GenerateSelfText::AiBuilder.call(chapter)

      payload[:mechanical] = mechanical_stats
      payload[:ai] = ai_stats
    end

    remaining = TradeTariffBackend.redis.decr(GenerateSelfTextWorker::REDIS_KEY)
    if remaining <= 0
      SelfTextGenerator::Instrumentation.generation_completed
      GenerateSelfTextReindexWorker.perform_async
    end
  rescue StandardError => e
    SelfTextGenerator::Instrumentation.chapter_failed(
      chapter_sid:,
      chapter_code: chapter&.short_code,
      error: e,
    )
    raise
  end
end
