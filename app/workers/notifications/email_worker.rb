module Notifications
  class EmailWorker
    include Sidekiq::Worker

    # Cap retries: Notify outages must not use Sidekiq's default (25) and crowd the default queue.
    sidekiq_options queue: :default, retry: 3

    def perform(email, template_id, personalisation, status_check_worker_class, status_check_args)
      notification = client.send_email(email, template_id, personalisation, nil, nil)
      notification_uuid = notification.notification_uuid

      begin
        status_check_worker_class.constantize.perform_in(
          GovukNotifierStatusCheckWorker::CHECK_DELAY, *status_check_args, notification_uuid
        )
      rescue StandardError => e
        Rails.logger.error(
          "notifications_email_worker_status_check_schedule_failed: #{e.class.name}: #{e.message} " \
          "status_check_worker_class=#{status_check_worker_class} status_check_args=#{status_check_args.inspect} " \
          "notification_uuid=#{notification_uuid}",
        )
      end
    end

    def client
      @client ||= GovukNotifier.new
    end
  end
end
