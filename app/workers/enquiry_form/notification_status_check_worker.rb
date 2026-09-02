class EnquiryForm::NotificationStatusCheckWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  PIPELINE = 'enquiry_form'.freeze

  def perform(reference, audience, notification_uuid)
    Notifications::DeliveryStatusChecker.new(
      notification_uuid,
      pipeline: PIPELINE,
      identifier: "#{reference}:#{audience}",
    ).call
  end
end
