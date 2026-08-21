require_relative '../lib/notifications/instrumentation'
require_relative '../lib/notifications/logger'

class CustomsTariffUpdateNotifierService
  PIPELINE = 'customs_tariff_update'.freeze
  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :notifications, :customs_tariff_update)

  def initialize(version)
    @version = version
  end

  def call
    email = TradeTariffBackend.support_email

    if email.blank?
      Notifications::Instrumentation.send_skipped(pipeline: PIPELINE, identifier: @version, reason: 'recipient_not_configured')
      return
    end

    update = CustomsTariffUpdate[@version]

    if update.nil?
      Notifications::Instrumentation.send_skipped(pipeline: PIPELINE, identifier: @version, reason: 'update_not_found')
      return
    end

    changes = CustomsTariffUpdateChangeSummary.new(update).call
    personalisation = build_personalisation(update, changes)

    Notifications::EnqueueService.new([@version], pipeline: PIPELINE) { |version|
      status_check_args = [version]
      Notifications::EmailWorker.perform_async(email, TEMPLATE_ID, personalisation, 'CustomsTariffUpdateNotificationStatusCheckWorker', status_check_args)
    }.call
  end

private

  def build_personalisation(update, changes)
    {
      'version' => update.version,
      'document_type' => document_type_label,
      'document_created_on' => update.document_created_on&.iso8601 || 'Not available',
      'document_url' => update.source_url.presence || 'Not available',
      'imported_on' => update.created_at&.iso8601,
      'entry_into_force_on' => update.validity_start_date&.iso8601,
      'chapter_ids' => changes[:chapter_ids].join(', '),
      'section_ids' => changes[:section_ids].join(', '),
    }
  end

  def document_type_label
    TradeTariffBackend.uk? ? 'UK Customs Tariff' : 'XI Combined Nomenclature'
  end
end
