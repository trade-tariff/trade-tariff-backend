RSpec.describe Api::V2::QuotaOrderNumbersController, type: :request do
  describe '#index' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      get '/uk/api/quota_order_numbers', headers: request_headers
    end

    before do
      create(
        :quota_order_number,
        :with_quota_definition,
        :current,
        :current_definition,
        quota_definition_sid: 1,
        quota_order_number_sid: 5,
        quota_order_number_id: '000001',
      )
    end

    it_behaves_like 'a successful jsonapi response'

    it 'calls the CachedQuotaOrderNumberService' do
      allow(CachedQuotaOrderNumberService).to receive(:new).and_call_original
      api_response
      expect(CachedQuotaOrderNumberService).to have_received(:new)
    end
  end
end
