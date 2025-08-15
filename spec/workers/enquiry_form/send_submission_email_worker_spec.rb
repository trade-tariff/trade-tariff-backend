# spec/workers/enquiry_form/send_submission_email_worker_spec.rb
require "rails_helper"
require "sidekiq/testing"

RSpec.describe EnquiryForm::SendSubmissionEmailWorker, type: :worker do
  describe ".perform_async" do
    let(:enquiry_form_data) do
      {
        name: "John Doe",
        company_name: "Doe & Co Inc.",
        job_title: "CEO",
        email: "john@example.com",
        enquiry_category: "Quotas",
        enquiry_description: "I have a question about quotas",
        reference_number: "ABC123",
        created_at: "2025-08-15 10:00"
      }.to_json
    end

    let(:csv_data) { "csv,data" }

    before do
      Sidekiq::Worker.clear_all
    end

    it "enqueues the job on the mailers queue with the correct args" do
      expect {
        described_class.perform_async(enquiry_form_data, csv_data)
      }.to change(described_class.jobs, :size).by(1)

      job = described_class.jobs.last
      expect(job["queue"]).to eq("mailers")
      expect(job["args"]).to eq([enquiry_form_data, csv_data])
    end
  end
end
