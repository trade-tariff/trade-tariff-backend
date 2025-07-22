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

  before do
    allow(EnquiryForm::CsvGeneratorService).to receive_message_chain(:new, :generate).and_return('csv,data,here')
    allow(EnquiryForm::CsvUploaderService).to receive_message_chain(:new, :upload)
  end

  describe 'POST #create' do
    context 'when the form submission is valid' do
      it 'returns a successful 200 response' do
        post '/api/v2/enquiry_form/submissions', params: { data: { attributes: form_submission_data } }

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['data']['attributes']['reference_number']).not_to be_nil
      end
    end

    context 'when the form submission is invalid' do
      it 'returns an unprocessable entity response' do
        post '/api/v2/enquiry_form/submissions', params: { data: { attributes: {} } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
