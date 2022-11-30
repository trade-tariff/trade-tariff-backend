RSpec.describe Api::V2::QuotaOrderNumbersController, type: :controller do
  describe '#index' do
    subject(:do_request) { get :index }

    let(:json_body) { JSON.parse(do_request.body) }
    let(:validity_end_date) { nil }

    before do
      create(
        :quota_order_number,
        :with_quota_definition,
        :current,
        :current_definition,
        quota_definition_sid: 1,
        quota_order_number_sid: 5,
        quota_order_number_id: '000001',
        validity_end_date:,
      )

      allow(TimeMachine).to receive(:at).and_call_original
      allow(Rails.cache).to receive(:fetch).and_call_original
    end

    it { is_expected.to have_http_status(:success) }

    it 'returns all the records' do
      expect(json_body['data']).to eq(
        [
          {
            'id' => '000001',
            'type' => 'quota_order_number',
            'attributes' => {
              'quota_order_number_sid' => 5,
              'validity_start_date' => 4.years.ago.beginning_of_day.as_json,
              'validity_end_date' => nil,
            },
            'relationships' => {
              'quota_definition' => { 'data' => { 'id' => '1', 'type' => 'quota_definition' } },
            },
          },
        ],
      )
    end

    context 'when the validity_end_date is set to a past date' do
      let(:validity_end_date) { 1.day.ago }

      it { expect(json_body['data']).to eq [] }
    end

    it 'returns all the includes' do
      expect(json_body['included']).to include_json(
        [
          { 'id' => '1', 'type' => 'quota_definition' },
        ],
      )
    end

    it 'rails cache receives fetch with the correct key' do
      do_request
      expect(Rails.cache).to have_received(:fetch).with("_quota-order-numbers-#{Time.zone.today.iso8601}", expires_in: 1.day)
    end
  end
end
