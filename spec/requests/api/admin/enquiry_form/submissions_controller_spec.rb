RSpec.describe Api::Admin::EnquiryForm::SubmissionsController, type: :request do
let(:enquiry_form_submission) { create('enquiry_form_submission') }

  describe "GET index" do
    it "returns a successful 200 response" do
      enquiry_form_submission

      authenticated_get "/admin/enquiry_form/submissions"

      expect(response).to have_http_status(:ok)
    end
  end
end
