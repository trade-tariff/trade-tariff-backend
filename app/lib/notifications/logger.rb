require 'active_support/log_subscriber'

module Notifications
  class Logger < ActiveSupport::LogSubscriber
    def send_skipped(event)
      error log_entry(event: 'send_skipped', pipeline: event.payload[:pipeline], identifier: event.payload[:identifier], reason: event.payload[:reason])
    end

    def enqueue_retrying(event)
      error log_entry(
        event: 'enqueue_retrying',
        pipeline: event.payload[:pipeline],
        item: event.payload[:item],
        attempt: event.payload[:attempt],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def enqueue_failed(event)
      error log_entry(event: 'enqueue_failed', pipeline: event.payload[:pipeline], items: event.payload[:items], attempts: event.payload[:attempts])
    end

    def delivery_failed(event)
      error log_entry(
        event: 'delivery_failed',
        pipeline: event.payload[:pipeline],
        identifier: event.payload[:identifier],
        notification_uuid: event.payload[:notification_uuid],
        status: event.payload[:status],
      )
    end

  private

    def log_entry(data)
      data.merge(service: 'notifications', timestamp: Time.current.iso8601).to_json
    end
  end
end

Notifications::Logger.attach_to :notifications unless Rails.env.test?
