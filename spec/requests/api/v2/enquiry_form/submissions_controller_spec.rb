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
    let(:reference_number) { 'ABC12345' }

    let(:frozen_time) { Time.zone.parse('2025-12-08 12:00:00') }

    before do
      travel_to frozen_time

      allow(CreateReferenceNumberService).to receive(:new).and_return(
        instance_double(CreateReferenceNumberService, call: reference_number),
      )

      allow(Api::V2::EnquiryForm::SubmissionSerializer).to receive(:new).and_call_original

      allow(::EnquiryForm::SendSubmissionEmailWorker).to receive(:perform_async)
      allow(Rails.cache).to receive(:write)
    end

    after do
      travel_back
    end

    it 'returns 201 created with reference number' do
      post api_enquiry_form_submissions_path,
           params: { data: { attributes: params } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data']['id']).to eq(reference_number)
    end

    it 'caches the data and enqueues the email worker with the reference only' do
      post api_enquiry_form_submissions_path,
           params: { data: { attributes: params } },
           headers: headers,
           as: :json

      expected_payload = params.merge(
        reference_number: reference_number,
        created_at: frozen_time.strftime('%Y-%m-%d %H:%M'),
      ).to_json

      expect(Rails.cache).to have_received(:write).with(
        "enquiry_form_#{reference_number}",
        expected_payload,
        expires_in: 1.hour,
      )

      expect(::EnquiryForm::SendSubmissionEmailWorker).to have_received(:perform_async).with(reference_number)
    end

    context 'when required params are missing' do
      it 'returns a 422 Unprocessable Content with errors' do
        post api_enquiry_form_submissions_path,
             params: { data: nil },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
