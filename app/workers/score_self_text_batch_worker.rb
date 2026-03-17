class ScoreSelfTextBatchWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: 3, slack_alerts: false

  def perform(sids, chapter_code = nil)
    return if sids.empty?

    SelfTextConfidenceScorer.new.score(sids, chapter_code:)
  end
end
