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

    it 'returns current quota order numbers with their definitions' do
      body = JSON.parse(api_response.body)

      expect(body).to include_json(
        'data' => [{ 'type' => 'quota_order_number', 'attributes' => { 'quota_order_number_sid' => 5 } }],
        'included' => [{ 'type' => 'quota_definition', 'relationships' => { 'measures' => { 'data' => [] } } }],
      )
    end

    it 'returns quota order numbers created since the previous request' do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      get '/uk/api/quota_order_numbers', headers: request_headers

      create(
        :quota_order_number,
        :with_quota_definition,
        :current,
        :current_definition,
        quota_definition_sid: 2,
        quota_order_number_sid: 6,
        quota_order_number_id: '000002',
      )
      get '/uk/api/quota_order_numbers', headers: request_headers

      expect(JSON.parse(response.body)['data'].size).to eq(2)
    end
  end
end
