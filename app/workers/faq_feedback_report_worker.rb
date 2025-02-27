class FaqFeedbackReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform(deliver_email = true)
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
