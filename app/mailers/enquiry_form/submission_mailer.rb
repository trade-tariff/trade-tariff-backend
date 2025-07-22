class EnquiryForm::SubmissionMailer < ApplicationMailer
  layout 'enquiry_form/mailer'
  default to: TradeTariffBackend.support_email

  def send_email(enquiry_form)
    @enquiry_form = enquiry_form
    mail(to: TradeTariffBackend.support_email, subject: "Enquiry Form Submission")
  end
end
