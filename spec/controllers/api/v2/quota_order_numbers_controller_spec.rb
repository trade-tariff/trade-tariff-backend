RSpec.describe Api::V2::QuotaOrderNumbersController, type: :controller do
  describe '#index' do
    subject(:do_request) { get :index }

    let(:json_body) { JSON.parse(do_request.body) }

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

      allow(TimeMachine).to receive(:at).and_call_original
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
              'validity_start_date' => Date.current.ago(4.years).as_json,
              'validity_end_date' => nil,
            },
            'relationships' => {
              'quota_definition' => { 'data' => { 'id' => '1', 'type' => 'quota_definition' } },
            },
          },
        ],
      )
    end

    it 'returns all the includes' do
      expect(json_body['included']).to include_json(
        [
          { 'id' => '1', 'type' => 'quota_definition' },
        ],
      )
    end

    it 'the TimeMachine receives the correct Date' do
      do_request
      expect(TimeMachine).to have_received(:at).with(Time.zone.today)
    end
  end
end
