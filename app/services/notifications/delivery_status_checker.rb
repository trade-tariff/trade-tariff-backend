require_relative '../../lib/notifications/instrumentation'
require_relative '../../lib/notifications/logger'

module Notifications
  class DeliveryStatusChecker
    FAILURE_STATUSES = [
      GovukNotifier::PERMANENT_FAILURE,
      GovukNotifier::TEMPORARY_FAILURE,
      GovukNotifier::TECHNICAL_FAILURE,
    ].freeze

    def initialize(notification_uuid, pipeline:, identifier:)
      @notification_uuid = notification_uuid
      @pipeline = pipeline
      @identifier = identifier
    end

    def call
      return if @notification_uuid.blank?

      status = GovukNotifier.new.get_email_status(@notification_uuid)
      return unless FAILURE_STATUSES.include?(status)

      Instrumentation.delivery_failed(pipeline: @pipeline, identifier: @identifier, notification_uuid: @notification_uuid, status:)
      notify_slack("#{@pipeline}: notification delivery failed for #{@identifier} (status: #{status}) — check logs")
      status
    end

  private

    def notify_slack(message)
      SlackNotifierService.call(message)
    rescue StandardError => e
      Rails.logger.error("#{@pipeline}_notification_slack_failed: #{e.class.name}: #{e.message}")
    end
  end
end
