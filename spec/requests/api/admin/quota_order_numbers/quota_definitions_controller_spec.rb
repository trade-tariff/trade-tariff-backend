RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaDefinitionsController, type: :request do
  describe 'GET #index' do
    subject(:do_request) do
      quota_order_number_id = create(
        :quota_order_number,
        :with_quota_definition,
        quota_balance_events: true,
      ).quota_order_number_id

      authenticated_get quota_definitions_current_api_quota_order_number_path(id: quota_order_number_id)

      response
    end

    it_behaves_like 'a successful jsonapi response'
  end
end
