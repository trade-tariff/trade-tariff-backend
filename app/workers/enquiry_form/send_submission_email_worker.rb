class EnquiryForm::SendSubmissionEmailWorker
  include Sidekiq::Worker

  sidekiq_options queue: :mailers, retry: 5

  def perform(enquiry_form_data)
    submission = EnquiryForm::Submission.find(enquiry_form_data[:id]).first
    submission.update(email_status: 'Pending') if submission.email_status == 'Failed'
    message = ::EnquiryForm::SubmissionMailer.send_email(enquiry_form_data).deliver_now

    if message.delivered?
      submission.update(email_status: 'Sent', submitted_at: Time.zone.now)
    else
      submission.update(email_status: 'Failed')
      Rails.logger.error("Failed to send enquiry form email: #{enquiry_form_data[:reference_number]}")
      raise 'Email not delivered'
    end
  end
end
