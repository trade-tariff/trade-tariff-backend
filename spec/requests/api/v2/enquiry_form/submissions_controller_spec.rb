RSpec.describe Api::V2::EnquiryForm::SubmissionsController, :v2 do
  describe 'POST #create' do
    let(:reference_number) { 'ABC12345' }

    before do
      allow(CreateReferenceNumberService).to receive(:new).and_return(
        instance_double(CreateReferenceNumberService, call: reference_number),
      )
      allow(::EnquiryForm::SendSubmissionEmailWorker).to receive(:perform_async)
      allow(::EnquiryForm::SendTradeTariffSubmissionEmailWorker).to receive(:perform_in)
    end

    after do
      Sidekiq.redis { |conn| conn.del(::EnquiryForm::SendSubmissionEmailWorker.cache_key(reference_number)) }
    end

    it 'preserves the existing V2 submission contract' do
      post api_enquiry_form_submissions_path,
           params: {
             data: {
               attributes: {
                 email: 'john@example.com',
                 enquiry_category: 'Quotas',
                 enquiry_description: 'I have a question.',
               },
             },
           },
           as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body).dig('data', 'id')).to eq(reference_number)
      expect(::EnquiryForm::SendSubmissionEmailWorker).to have_received(:perform_async).with(reference_number)
    end
  end
end
