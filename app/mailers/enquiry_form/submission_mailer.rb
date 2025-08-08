class EnquiryForm::SubmissionMailer < ApplicationMailer
  layout 'enquiry_form/mailer'
  default to: TradeTariffBackend.support_email

  def send_email(enquiry_form)
    @enquiry_form = enquiry_form
    mail(to: TradeTariffBackend.support_email, subject: "[#{@enquiry_form[:enquiry_category]}] Online Tariff Tool - Enquiry - reference: #{@enquiry_form[:reference_number]}")
  end
end
