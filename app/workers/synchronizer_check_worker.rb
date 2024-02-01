class SynchronizerCheckWorker
  include Sidekiq::Worker

  RECENCY_THRESHOLD = 5 # days ago

  def perform(check_since = RECENCY_THRESHOLD)
    latest_qbe = QuotaBalanceEvent::Operation.order_by(Sequel.desc(:oid)).first

    return true if latest_qbe && latest_qbe.created_at > check_since.days.ago

    msg = <<~EOMSG
      #{sync_service_name} sync problem - last update to Quota Balance Events was over #{check_since} days ago

      Last update was at #{latest_qbe&.created_at}. Please investigate promptly.
    EOMSG

    Sentry.capture_message(msg)
    Rails.logger.warn(msg)
  end

  private

  def sync_service_name
    TradeTariffBackend.uk? ? 'CDS' : 'Taric'
  end
end
