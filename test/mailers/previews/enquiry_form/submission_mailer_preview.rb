require 'factory_bot'
require Rails.root.join('spec', 'factories', 'enquiry_form', 'submission_factory')


class EnquiryForm::SubmissionMailerPreview < ActionMailer::Preview
  def send_email
    form_data = {
      name: 'John Doe',
      company_name: 'John Doe Ltd',
      job_title: 'Customs Officer',
      email: 'john@acme.com',
      enquiry_category: 'Quotas',
      enquiry_description: 'I need help with my quotas',
    }

    enquiry_form = form_data.merge(::FactoryBot.build(:enquiry_form_submission))
    ::EnquiryForm::SubmissionMailer.send_email(enquiry_form)
  end
end
