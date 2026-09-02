class EnquiryForm::SendTradeTariffSubmissionEmailWorker < EnquiryForm::SendSubmissionEmailWorker
  sidekiq_options retry: 3

  def perform(reference)
    perform_delivery(reference, EnquiryForm::Submission::TRADE_TARIFF_AUDIENCE)
  end
end
