require_relative '../../lib/notifications/instrumentation'
require_relative '../../lib/notifications/logger'

module Notifications
  class EnqueueService
    MAX_ATTEMPTS = 3
    RETRY_DELAY = 30.seconds

    Result = Data.define(:failed_items, :attempts)

    def initialize(items, pipeline:, max_attempts: MAX_ATTEMPTS, retry_delay: RETRY_DELAY, &enqueue)
      @items = items
      @pipeline = pipeline
      @max_attempts = max_attempts
      @retry_delay = retry_delay
      @enqueue = enqueue
    end

    def call
      pending = @items
      attempt = 0

      until pending.empty? || attempt >= @max_attempts
        attempt += 1
        pending = attempt_enqueue(pending, attempt)
        sleep(@retry_delay) if pending.any? && attempt < @max_attempts
      end

      if pending.any?
        Instrumentation.enqueue_failed(pipeline: @pipeline, items: pending, attempts: attempt)
        notify_slack("#{@pipeline}: failed to enqueue notification for #{pending.join(', ')} after #{attempt} attempts — check logs")
      end

      Result.new(failed_items: pending, attempts: attempt)
    end

  private

    def attempt_enqueue(pending, attempt)
      pending.each_with_object([]) do |item, failed|
        @enqueue.call(item)
      rescue StandardError => e
        failed << item
        Instrumentation.enqueue_retrying(pipeline: @pipeline, item:, attempt:, error_class: e.class.name, error_message: e.message)
      end
    end

    def notify_slack(message)
      SlackNotifierService.call(message)
    rescue StandardError => e
      Rails.logger.error("#{@pipeline}_notification_slack_failed: #{e.class.name}: #{e.message}")
    end
  end
end
