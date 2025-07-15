RSpec.describe Api::Admin::EnquiryForm::SubmissionsController, type: :request do
  let(:form_submission_data) do
    {
      name: "John Johnson",
      company_name: "Company LTD",
      job_title: "Partnerships Manager",
      email: "john.johnson@example.com",
      enquiry_category: "Quotas",
      enquiry_description: "How much quota do you have left for this commodity code?",
    }
  end
  let(:enquiry_form_submission) { create(:enquiry_form_submission, enquiry_form: enquiry_form) }

  describe "GET index" do
    it "returns a successful 200 response" do
      get "/admin/enquiry_forms/submissions"

      expect(response).to have_http_status(:ok)
    end
  end
end
