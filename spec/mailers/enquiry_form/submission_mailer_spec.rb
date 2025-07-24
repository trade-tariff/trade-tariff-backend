RSpec.describe EnquiryForm::SubmissionMailer, type: :mailer do
  describe "send_email" do
    let(:submission) { create(:enquiry_form_submission) }
    let(:form_data) {
      {
        name: "John Doe",
        company_name: "John Doe Ltd",
        job_title: "Customs Officer",
        email: "john@acme.com",
        enquiry_category: "Quotas",
        enquiry_description: "I need help with my quotas"
      }
    }

    let(:enquiry_form) { form_data.merge(submission) }

    it "enqueues the email to support with the enquiry form details" do
      expect {
        described_class.send_email(enquiry_form).deliver_later
      }.to have_enqueued_mail(described_class, :send_email).with(enquiry_form)
    end
  end
end
