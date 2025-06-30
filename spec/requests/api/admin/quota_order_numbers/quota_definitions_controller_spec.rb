RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaDefinitionsController, :admin do
  before do
    allow(TimeMachine).to receive(:no_time_machine).and_call_original
  end

  describe 'GET #show' do
    subject(:do_request) do
      quota_order_number = create(:quota_order_number, :with_quota_definition, quota_balance_events: true)

      quota_order_number_id = quota_order_number.quota_order_number_id
      id = quota_order_number.quota_definition.quota_definition_sid

      authenticated_get api_quota_order_number_quota_definition_path(quota_order_number_id:, id:)

      response
    end

    it_behaves_like 'a successful jsonapi response'
  end

  describe 'GET #index' do
    subject(:do_request) do
      quota_order_number = create(:quota_order_number, :with_quota_definition, quota_balance_events: true)

      authenticated_get api_quota_order_number_quota_definitions_path(
        quota_order_number_id: quota_order_number.quota_order_number_id,
      )

      response
    end

    it_behaves_like 'a successful jsonapi response'
  end
end
