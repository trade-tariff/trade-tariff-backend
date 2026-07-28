class Appendix5aPopulatorService
  MAX_ENQUEUE_ATTEMPTS = 3
  ENQUEUE_RETRY_DELAY = 30.seconds

  def call
    Rails.logger.info 'Populating Appendix 5a'

    Appendix5a.unrestrict_primary_key
    Appendix5a.db.transaction do
      added_guidance.each(&:save)
      changed_guidance.each(&:save)
      removed_guidance.each(&:destroy)
    end
    Appendix5a.restrict_primary_key

    notify

    Rails.logger.info 'Finished populating Appendix 5a'
  end

private

  def removed_guidance
    @removed_guidance ||= begin
      removed_document_codes = existing_document_codes - new_guidance.keys

      existing_guidance.select do |guidance|
        removed_document_codes.include?(guidance.document_code)
      end
    end
  end

  def added_guidance
    @added_guidance ||= begin
      added_document_codes = new_guidance.keys - existing_document_codes

      added_document_codes.map do |document_code|
        guidance = new_guidance[document_code]

        certificate_type_code = document_code[0]
        certificate_code = document_code[1..]
        cds_guidance = guidance['guidance_cds']

        Appendix5a.new(
          certificate_type_code:,
          certificate_code:,
          cds_guidance:,
        )
      end
    end
  end

  def changed_guidance
    @changed_guidance ||= begin
      changed_document_codes = new_guidance.keys & existing_document_codes

      changed_document_codes.each_with_object([]) do |document_code, acc|
        existing_guidance.each do |guidance|
          next unless guidance.document_code == document_code

          guidance.cds_guidance = new_guidance[document_code]['guidance_cds']

          if guidance.column_changes.any?
            acc << guidance
          end
        end
      end
    end
  end

  def existing_document_codes
    @existing_document_codes ||= existing_guidance.map(&:document_code)
  end

  def new_guidance
    @new_guidance ||= Appendix5a.fetch_latest
  end

  def existing_guidance
    @existing_guidance ||= Appendix5a.all
  end

  def notify
    return if no_guidance_changes?

    message = "Appendix 5a has been updated with #{added_guidance.count} new, "
    message += "#{changed_guidance.count} changed and "
    message += "#{removed_guidance.count} removed guidance documents"

    Rails.logger.info message

    notify_slack(message)

    emails = TradeTariffBackend.cupid_team_to_emails

    if emails.empty?
      Rails.logger.error 'Appendix 5a guidance changed but CUPID_TEAM_TO_EMAILS is not configured — no notification emails were sent'
      return
    end

    enqueue_notifications(emails.each_index.to_a, added_guidance.count, changed_guidance.count, removed_guidance.count)
  end

  def enqueue_notifications(pending, new_count, changed_count, removed_count)
    attempt = 0

    until pending.empty? || attempt >= MAX_ENQUEUE_ATTEMPTS
      attempt += 1
      pending = attempt_enqueue(pending, attempt, new_count, changed_count, removed_count)
      sleep(ENQUEUE_RETRY_DELAY) if pending.any? && attempt < MAX_ENQUEUE_ATTEMPTS
    end

    return if pending.empty?

    pending.each do |recipient_index|
      log_notification_event(event: 'enqueue', state: 'failed', recipient_index:, attempt:)
    end

    notify_slack(
      "Appendix 5a: failed to enqueue notification for recipient index #{pending.join(', ')} after #{MAX_ENQUEUE_ATTEMPTS} attempts — check logs",
    )
  end

  def notify_slack(message)
    SlackNotifierService.call(message)
  rescue StandardError => e
    Rails.logger.error("appendix5a_notification_slack_failed: #{e.class.name}: #{e.message}")
  end

  def attempt_enqueue(pending, attempt, new_count, changed_count, removed_count)
    pending.each_with_object([]) do |recipient_index, failed|
      Appendix5aEmailWorker.perform_async(recipient_index, new_count, changed_count, removed_count)
    rescue StandardError => e
      failed << recipient_index
      log_notification_event(event: 'enqueue', state: 'retrying', recipient_index:, attempt:, exception: e)
    end
  end

  def log_notification_event(event:, state:, **fields)
    exception = fields.delete(:exception)
    payload = { event: "appendix5a_notification_#{event}", state:, **fields }
    payload[:exception_class] = exception.class.name if exception
    payload[:exception_message] = exception.message if exception

    message = "#{payload[:event]} #{state}: #{payload}"

    state.in?(%w[retrying failed]) ? Rails.logger.error(message) : Rails.logger.info(message)
  end

  def no_guidance_changes?
    added_guidance.empty? && changed_guidance.empty? && removed_guidance.empty?
  end
end
