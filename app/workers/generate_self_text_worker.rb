require_relative '../lib/self_text_generator/instrumentation'
require_relative '../lib/self_text_generator/logger'

class GenerateSelfTextWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false, slack_alerts: false

  REDIS_KEY = 'self_text:remaining'.freeze

  def perform
    chapters = TimeMachine.now { Chapter.actual.all }

    SelfTextGenerator::Instrumentation.generation_started(
      total_chapters: chapters.size,
    )

    TradeTariffBackend.redis.set(REDIS_KEY, chapters.size)

    chapters.each do |chapter|
      GenerateSelfTextChapterWorker.perform_async(chapter.goods_nomenclature_sid)
    end
  end
end
