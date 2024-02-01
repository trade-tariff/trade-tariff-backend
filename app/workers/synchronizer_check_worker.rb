class SynchronizerCheckWorker
  include Sidekiq::Worker

  RECENCY_THRESHOLD = 5 # days ago

  def perform(check_since = RECENCY_THRESHOLD)
    latest_qbe = QuotaBalanceEvent::Operation.order_by(Sequel.desc(:oid)).first

    unless latest_qbe && latest_qbe.created_at >= check_since.days.ago
      msg = "Potential sync problem on #{TradeTariffBackend.service&.upcase} service - last update: #{latest_qbe&.created_at}"

      Sentry.capture_message(msg)
      Rails.logger.warn(msg)
    end
  end
end
