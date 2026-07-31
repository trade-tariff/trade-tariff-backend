class CustomsTariffUpdateNotificationStatusCheckWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  PIPELINE = 'customs_tariff_update'.freeze

  def perform(version, notification_uuid)
    Notifications::DeliveryStatusChecker.new(notification_uuid, pipeline: PIPELINE, identifier: version).call
  end
end
