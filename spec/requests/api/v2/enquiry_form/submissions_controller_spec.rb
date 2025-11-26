RSpec.describe Api::V2::EnquiryForm::SubmissionsController, :v2 do
  describe 'POST #create' do
    let(:params) do
      {
        name: 'John Doe',
        company_name: 'Doe & Co Inc.',
        job_title: 'CEO',
        email: 'john@example.com',
        enquiry_category: 'Quotas',
        enquiry_description: 'I have a question.',
      }
    end

    let(:headers) { { 'Content-Type' => 'application/json' } }

    let(:csv_data) { 'csv,data' }
    let(:reference_number) { 'ABC12345' }

    before do
      allow(controller).to receive(:set_reference_number) do
        controller.instance_variable_set(:@set_reference_number, reference_number)
      end

      csv_service = instance_double(EnquiryForm::CsvGeneratorService, generate: csv_data)
      allow(EnquiryForm::CsvGeneratorService).to receive(:new).and_return(csv_service)

      allow(EnquiryForm::SendSubmissionEmailWorker).to receive(:perform_async)

      serializer_double = instance_double(
        Api::V2::EnquiryForm::SubmissionSerializer,
        serializable_hash: { data: { id: reference_number, type: :"enquiry_form/submission" } },
      )
      allow(Api::V2::EnquiryForm::SubmissionSerializer).to receive(:new).and_return(serializer_double)
    end

    it 'returns 201 created with reference number' do
      post api_enquiry_form_submissions_path,
           params: { data: { attributes: params } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data']['id']).to eq(reference_number)
    end

    it 'generates CSV and enqueues email worker' do
      expect(::EnquiryForm::CsvGeneratorService).to receive(:new).and_call_original # rubocop:disable RSpec/MessageSpies

      expect(::EnquiryForm::SendSubmissionEmailWorker).to receive(:perform_async) do |json_data, csv| # rubocop:disable RSpec/MessageSpies
        parsed = JSON.parse(json_data)
        expect(parsed['name']).to eq('John Doe')
        expect(parsed['company_name']).to eq('Doe & Co Inc.')
        expect(parsed['reference_number']).to eq(reference_number)
        expect(parsed).to have_key('created_at')
        expect(csv).to eq(csv_data)
      end

      post api_enquiry_form_submissions_path,
           params: { data: { attributes: params } },
           headers: headers,
           as: :json
    end

    context 'when required params are missing' do
      it 'returns a 422 Unporcessable Content with errors' do
        post api_enquiry_form_submissions_path,
             params: { data: nil },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
