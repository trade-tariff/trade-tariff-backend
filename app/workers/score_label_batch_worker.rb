class ScoreLabelBatchWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: 3, slack_alerts: false

  def perform(sids)
    sids = Array(sids)
    return if sids.empty?

    GoodsNomenclatureSelfText.regenerate_search_embeddings(sids)
    LabelConfidenceScorer.new.score(sids)
  end
end
