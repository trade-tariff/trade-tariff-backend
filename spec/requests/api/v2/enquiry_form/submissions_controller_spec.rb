RSpec.describe Api::Admin::EnquiryForm::SubmissionsController, type: :request do
  let(:form_submission_data) do
    {
      name: 'John Johnson',
      company_name: 'Company LTD',
      job_title: 'Partnerships Manager',
      email: 'john.johnson@example.com',
      enquiry_category: 'Quotas',
      enquiry_description: 'How much quota do you have left for this commodity code?',
    }
  end

  describe 'POST #create' do
    it 'returns a successful 200 response' do
      post '/api/v2/enquiry_form/submissions', params: form_submission_data

      expect(response).to have_http_status(:ok)
    end
  end
end
