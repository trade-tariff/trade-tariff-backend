class ClearInvalidSearchReferences
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_minute, retry: false

  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :search_references, :invalidation_alert)
  WHODUNNIT = 'ClearInvalidSearchReferences'.freeze

  def perform
    removed = []

    TradeTariffRequest.set(whodunnit: WHODUNNIT) do
      SearchReference.each do |search_reference|
        process(search_reference, removed:)
      end
    end

    return if removed.empty?

    logger.info("Removed search references: #{removed.map { |r| SearchReferences::ChangeLineFormatter.format_line(r) }.join('; ')}")

    notify(removed)
  end

private

  def process(search_reference, removed:)
    result = SearchReferences::InvalidationReasonService.call(search_reference)

    return unless result[:removal_alert_required]

    # destroy (not delete) so a version records the reference's last known state. The version
    # also keeps the removal reason, because later tariff data changes can change the result
    # of InvalidationReasonService.
    search_reference.version_metadata = {
      removal_reason: result[:reason].to_s,
      successor_ids: Array(result[:successor_ids]),
    }
    search_reference.destroy
    removed << result
  rescue StandardError => e
    logger.error("ClearInvalidSearchReferences: failed to process search reference #{search_reference.id}: #{e.class.name}: #{e.message}")
  end

  def notify(removed)
    email = TradeTariffBackend.feedback_email
    return if email.blank?

    client.send_email(email, TEMPLATE_ID, personalisation(removed))
  rescue StandardError => e
    logger.error("ClearInvalidSearchReferences: failed to send invalidation alert email: #{e.class.name}: #{e.message}")
  end

  def personalisation(removed)
    {
      removed_count: removed.size,
      has_missing: by_reason(removed, :missing).any?,
      missing_list: format_list(by_reason(removed, :missing)),
      has_expired: by_reason(removed, :expired).any?,
      expired_list: format_list(by_reason(removed, :expired)),
      has_superseded: by_reason(removed, :superseded).any?,
      superseded_list: format_list(by_reason(removed, :superseded)),
      has_unknown: by_reason(removed, :unknown).any?,
      unknown_list: format_list(by_reason(removed, :unknown)),
    }
  end

  def by_reason(results, reason)
    results.select { |result| result[:reason] == reason }
  end

  def format_list(results)
    SearchReferences::ChangeLineFormatter.format_list(results)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
