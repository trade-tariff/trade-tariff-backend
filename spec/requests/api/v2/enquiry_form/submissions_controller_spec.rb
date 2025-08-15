require 'rails_helper'

RSpec.describe Api::V2::EnquiryForm::SubmissionsController, :v2 do
  let(:controller) { described_class.new }

  describe 'POST #create' do
    let(:params) do
      {
        name: 'John Doe',
        company_name: 'Doe & Co Inc.',
        job_title: 'CEO',
        email: 'john@example.com',
        enquiry_category: 'Quotas',
        enquiry_description: 'I have a question.'
      }
    end

    let(:headers) { { 'Content-Type' => 'application/json' } }

    let(:csv_data) { 'csv,data' }
    let(:reference_number) { 'ABC12345' }

    before do
      # Stub before_action reference number
      allow(controller).to receive(:set_reference_number) do
        controller.instance_variable_set(:@reference_number, reference_number)
      end

      # Stub services
      csv_service = instance_double('EnquiryForm::CsvGeneratorService', generate: csv_data)
      allow(EnquiryForm::CsvGeneratorService).to receive(:new).and_return(csv_service)

      allow(EnquiryForm::SendSubmissionEmailWorker).to receive(:perform_async)

      serializer_double = instance_double(
        Api::V2::EnquiryForm::SubmissionSerializer,
        serializable_hash: { data: { id: reference_number, type: :"enquiry_form/submission" } }
      )

      allow(Api::V2::EnquiryForm::SubmissionSerializer).to receive(:new).and_return(serializer_double)
    end

    it 'returns 201 created with reference number' do
      post api_enquiry_form_submissions_path, params: { data: { attributes: { params: params } } }, headers: headers, as: :json
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json[:data][:id]).to eq(reference_number)
    end

    it 'generates CSV and enqueues email worker' do
      expect(EnquiryForm::CsvGeneratorService).to receive(:new).and_call_original
      expect(EnquiryForm::SendSubmissionEmailWorker).to receive(:perform_async)
        .with(params.to_json, csv_data)
    end

    context 'when serializer raises error' do
      before do
        allow(Api::V2::EnquiryForm::SubmissionSerializer).to receive(:new).and_raise(StandardError, 'boom')
        error_serializer = double('ErrorSerializationService', call: { errors: ['boom'] })
        allow(Api::V2::ErrorSerializationService).to receive(:new).and_return(error_serializer)
      end

      it 'returns 422 with errors' do
        post api_enquiry_form_submissions_path, params: { data: { attributes: { params: params } } }, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('boom')
      end
    end
  end
end
