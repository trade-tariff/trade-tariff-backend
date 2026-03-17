require_relative '../lib/self_text_generator/instrumentation'
require_relative '../lib/self_text_generator/logger'

class GenerateSelfTextWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false, slack_alerts: false

  REDIS_KEY = 'self_text:remaining'.freeze

  def perform
    chapters = TimeMachine.now { chapters_needing_work }

    SelfTextGenerator::Instrumentation.generation_started(
      total_chapters: chapters.size,
    )

    TradeTariffBackend.redis.set(REDIS_KEY, chapters.size)

    chapters.each do |chapter|
      GenerateSelfTextChapterWorker.perform_async(chapter.goods_nomenclature_sid)
    end
  end

  private

  def chapters_needing_work
    gn = Sequel[:goods_nomenclatures]
    st = Sequel[:goods_nomenclature_self_texts]
    chapter_code_expr = Sequel.function(:substr, gn[:goods_nomenclature_item_id], 1, 2)

    chapter_codes_with_work = GoodsNomenclature
      .actual
      .non_hidden
      .exclude(gn[:goods_nomenclature_item_id] => Chapter.actual.select(:goods_nomenclature_item_id))
      .left_join(:goods_nomenclature_self_texts, st[:goods_nomenclature_sid] => gn[:goods_nomenclature_sid])
      .where(Sequel.expr(st[:goods_nomenclature_sid] => nil) | Sequel.expr(st[:stale] => true))
      .unordered
      .distinct
      .select_map(chapter_code_expr)

    return [] if chapter_codes_with_work.empty?

    Chapter.actual
      .where(Sequel.function(:substr, :goods_nomenclature_item_id, 1, 2) => chapter_codes_with_work)
      .all
  end
end
