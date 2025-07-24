class EnquiryForm::SendSubmissionEmailWorker
  include Sidekiq::Worker

  sidekiq_options queue: :mailers, retry: 5

  def perform(enquiry_form_data)
    parsed_data = JSON.parse(enquiry_form_data).symbolize_keys
    submission = EnquiryForm::Submission.find(parsed_data[:id]).first
    submission.update(email_status: 'Pending') if submission.email_status == 'Failed'

    begin
      ::EnquiryForm::SubmissionMailer.send_email(parsed_data).deliver_now
      submission.update(email_status: 'Sent', submitted_at: Time.zone.now)
      Rails.logger.info("Sent enquiry form email: #{parsed_data[:reference_number]}")
    rescue StandardError => e
      submission.update(email_status: 'Failed')
      Rails.logger.error("Failed to send enquiry form email: #{parsed_data[:reference_number]}")
      raise "Email not delivered: #{e.message}"
    end
  end
end
