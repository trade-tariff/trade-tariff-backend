class ScoreSelfTextBatchWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: 3, slack_alerts: false

  def perform(sids)
    return if sids.empty?

    SelfTextConfidenceScorer.new.score(sids)
  end
end
