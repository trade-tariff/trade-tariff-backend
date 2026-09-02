class EnquiryForm::NotificationStatusCheckWorker
  class PendingDeliveryError < StandardError; end

  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  CHECK_INTERVAL = 10.minutes
  MAX_CHECKS = 3
  PENDING_STATUSES = %w[created sending].freeze
  PIPELINE = 'enquiry_form'.freeze

  def perform(reference, audience, notification_uuid, check_count = 1)
    status = Notifications::DeliveryStatusChecker.new(
      notification_uuid,
      pipeline: PIPELINE,
      identifier: "#{reference}:#{audience}",
    ).call

    return unless PENDING_STATUSES.include?(status)

    if check_count >= MAX_CHECKS
      raise PendingDeliveryError,
            "Notify delivery is still #{status} after #{check_count} checks for #{reference}:#{audience}"
    end

    self.class.perform_in(
      CHECK_INTERVAL,
      reference,
      audience,
      notification_uuid,
      check_count + 1,
    )
  end
end
