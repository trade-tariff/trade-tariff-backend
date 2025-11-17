class CdsUpdateNotificationWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(notification_id)
    if TradeTariffBackend.uk?
      notification = CdsUpdateNotification.find(id: notification_id)
      if notification.present?
        CdsImporter.new(notification.cds_update, handler_classes: [CdsImporter::ExcelWriter]).import
      end
    end
  end
end
