class EnquiryForm::SendTradeTariffSubmissionEmailWorker < EnquiryForm::SendSubmissionEmailWorker
  # A longer retry window lets jobs enqueued by the web process wait for new worker tasks
  # during a rolling deployment, without changing the established HMRC job contract.
  sidekiq_options retry: 10

  def perform(reference)
    perform_delivery(reference, EnquiryForm::Submission::TRADE_TARIFF_AUDIENCE)
  end
end
