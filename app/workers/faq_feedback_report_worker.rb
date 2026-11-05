class FaqFeedbackReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: 1, retry_in: 1.hour

  DEFAULT_DELIVER_EMAIL = true

  def perform(deliver_email = DEFAULT_DELIVER_EMAIL)
    return if TradeTariffBackend.uk?

    if deliver_email
      send_faq_feedback_report_email
    end
  end

private

  def send_faq_feedback_report_email
    FaqFeedbackMailer.faq_feedback_message.deliver_now
  end
end
