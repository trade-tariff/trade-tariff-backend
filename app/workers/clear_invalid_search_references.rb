class ClearInvalidSearchReferences
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :search_references, :invalidation_alert)

  def perform
    removed = []
    flagged = []

    SearchReference.each do |search_reference|
      process(search_reference, removed:, flagged:)
    end

    return if removed.empty? && flagged.empty?

    logger.info("Removed search references: #{removed.map { |r| format_line(r) }.join('; ')}") if removed.any?
    logger.info("Flagged search references for review: #{flagged.map { |r| format_line(r) }.join('; ')}") if flagged.any?

    notify(removed, flagged)
  end

private

  def process(search_reference, removed:, flagged:)
    result = SearchReferences::InvalidationReasonService.call(search_reference)

    return unless result[:removal_alert_required]

    if result[:auto_deletion]
      search_reference.delete
      removed << result
    else
      flagged << result
    end
  rescue StandardError => e
    logger.error("ClearInvalidSearchReferences: failed to process search reference #{search_reference.id}: #{e.class.name}: #{e.message}")
  end

  def notify(removed, flagged)
    email = TradeTariffBackend.feedback_email
    return if email.blank?

    client.send_email(email, TEMPLATE_ID, personalisation(removed, flagged))
  rescue StandardError => e
    logger.error("ClearInvalidSearchReferences: failed to send invalidation alert email: #{e.class.name}: #{e.message}")
  end

  def personalisation(removed, flagged)
    {
      removed_count: removed.size,
      flagged_count: flagged.size,
      has_missing: by_reason(removed, :missing).any?,
      missing_list: format_list(by_reason(removed, :missing)),
      has_expired: by_reason(removed, :expired).any?,
      expired_list: format_list(by_reason(removed, :expired)),
      has_superseded: by_reason(flagged, :superseded).any?,
      superseded_list: format_list(by_reason(flagged, :superseded)),
      has_unknown: by_reason(flagged, :unknown).any?,
      unknown_list: format_list(by_reason(flagged, :unknown)),
    }
  end

  def by_reason(results, reason)
    results.select { |result| result[:reason] == reason }
  end

  def format_list(results)
    results.map { |result| "* #{format_line(result)}" }.join("\n")
  end

  def format_line(result)
    line = "#{result[:goods_nomenclature_item_id]} — #{result[:title]}"
    line += " (#{result[:goods_nomenclature_url]})" if result[:goods_nomenclature_url].present?
    line += " (successors: #{result[:successor_ids].join(', ')})" if result[:successor_ids].present?
    line
  end

  def client
    @client ||= GovukNotifier.new
  end
end
