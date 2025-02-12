RSpec.describe Api::V2::QuotaOrderNumbersController, type: :controller do
  routes { V2Api.routes }

  describe '#index' do
    subject(:do_request) { get :index }

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
      do_request
      expect(CachedQuotaOrderNumberService).to have_received(:new)
    end
  end
end
