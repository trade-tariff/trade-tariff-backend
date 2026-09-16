require_relative '../../lib/notifications/instrumentation'
require_relative '../../lib/notifications/logger'

module Notifications
  class EnqueueService
    # Raised by callers when every attempt to enqueue was exhausted. The
    # service itself still returns a Result: it is the caller that knows
    # whether an unenqueued notification should fail the surrounding job.
    class EnqueueFailedError < StandardError; end

    MAX_ATTEMPTS = 3
    RETRY_DELAY = 30.seconds

    Result = Data.define(:failed_items, :attempts, :pipeline) do
      def failure_message
        "#{pipeline}: failed to enqueue notification for #{failed_items.join(', ')} after #{attempts} attempts"
      end
    end

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

      result = Result.new(failed_items: pending, attempts: attempt, pipeline: @pipeline)

      if pending.any?
        Instrumentation.enqueue_failed(pipeline: @pipeline, items: pending, attempts: attempt)
        notify_slack("#{result.failure_message} — check logs")
      end

      result
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
