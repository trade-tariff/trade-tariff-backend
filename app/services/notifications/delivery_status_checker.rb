require_relative '../../lib/notifications/instrumentation'
require_relative '../../lib/notifications/logger'

module Notifications
  class DeliveryStatusChecker
    FAILURE_STATUSES = [
      GovukNotifier::PERMANENT_FAILURE,
      GovukNotifier::TEMPORARY_FAILURE,
      GovukNotifier::TECHNICAL_FAILURE,
    ].freeze

    METRIC_FAILURE_STATUSES = [
      GovukNotifier::PERMANENT_FAILURE,
      GovukNotifier::TECHNICAL_FAILURE,
    ].freeze

    METRIC_NAMESPACE = 'TradeTariff/Notify'.freeze

    def initialize(notification_uuid, pipeline:, identifier:)
      @notification_uuid = notification_uuid
      @pipeline = pipeline
      @identifier = identifier
    end

    def call
      return if @notification_uuid.blank?

      status = GovukNotifier.new.get_email_status(@notification_uuid)
      return status unless FAILURE_STATUSES.include?(status)

      Instrumentation.delivery_failed(pipeline: @pipeline, identifier: @identifier, notification_uuid: @notification_uuid, status:)
      notify_slack("#{@pipeline}: notification delivery failed for #{@identifier} (status: #{status}) — check logs")
      put_cloudwatch_metric(status)
      status
    end

  private

    def notify_slack(message)
      SlackNotifierService.call(message)
    rescue StandardError => e
      Rails.logger.error("#{@pipeline}_notification_slack_failed: #{e.class.name}: #{e.message}")
    end

    def put_cloudwatch_metric(status)
      return unless METRIC_FAILURE_STATUSES.include?(status)

      Aws::CloudWatch::Client.new.put_metric_data(
        namespace: METRIC_NAMESPACE,
        metric_data: [{
          metric_name: 'DeliveryFailures',
          value: 1,
          unit: 'Count',
          dimensions: [
            { name: 'Environment', value: Rails.env },
            { name: 'Pipeline', value: @pipeline },
          ],
        }],
      )
    rescue Aws::Errors::ServiceError => e
      Rails.logger.error("notify_cloudwatch_metric_failed: #{e.class.name}: #{e.message}")
    end
  end
end
