RSpec.describe Api::V2::Quotas::UtilizationSummaryController do
  describe 'GET #index' do
    subject(:do_request) do
      get '/uk/api/quotas/utilization_summary', params:, headers: request_headers(format: :json)
    end

    let(:json) { JSON.parse(response.body) }
    let(:params) { {} }

    context 'when no quota definitions exist' do
      before { do_request }

      it 'is successful with empty data' do
        expect(response).to be_successful
        expect(json['data']).to eq([])
      end

      it 'includes pagination meta' do
        expect(json.dig('meta', 'pagination')).to include('total_count' => 0)
      end
    end

    context 'when quota definitions exist' do
      let(:order_number_id) { '094011' }

      before do
        order_number = create(:quota_order_number, quota_order_number_id: order_number_id)
        create(:quota_definition,
               quota_order_number_id: order_number_id,
               quota_order_number_sid: order_number.quota_order_number_sid,
               initial_volume: 5000.0,
               measurement_unit_code: 'DTN')
        do_request
      end

      it 'returns utilization records' do
        expect(json['data'].length).to eq(1)
        expect(json['data'].first['type']).to eq('quota_utilization_summary')
      end

      it 'includes utilization attributes' do
        attrs = json['data'].first['attributes']
        expect(attrs['quota_order_number_id']).to eq(order_number_id)
        expect(attrs['initial_volume']).to eq(5000.0)
        expect(attrs['utilization_percentage']).to eq(0.0)
      end
    end

    context 'when filtering by measurement_unit_code' do
      before do
        on = create(:quota_order_number, quota_order_number_id: '094020')
        create(:quota_definition,
               quota_order_number_id: '094020',
               quota_order_number_sid: on.quota_order_number_sid,
               measurement_unit_code: 'DTN')

        on2 = create(:quota_order_number, quota_order_number_id: '094021')
        create(:quota_definition,
               quota_order_number_id: '094021',
               quota_order_number_sid: on2.quota_order_number_sid,
               measurement_unit_code: 'LTR')
        do_request
      end

      let(:params) { { filter: { measurement_unit_code: 'DTN' } } }

      it 'returns only definitions with the given unit code' do
        ids = json['data'].map { |r| r.dig('attributes', 'quota_order_number_id') }
        expect(ids).to include('094020')
        expect(ids).not_to include('094021')
      end
    end

    context 'when filtering by quota_type licensed' do
      before do
        licensed_on = create(:quota_order_number, quota_order_number_id: '094011')
        create(:quota_definition,
               quota_order_number_id: '094011',
               quota_order_number_sid: licensed_on.quota_order_number_sid)

        fcfs_on = create(:quota_order_number, quota_order_number_id: '090011')
        create(:quota_definition,
               quota_order_number_id: '090011',
               quota_order_number_sid: fcfs_on.quota_order_number_sid)
        do_request
      end

      let(:params) { { filter: { quota_type: 'licensed' } } }

      it 'returns only licensed quotas (3rd char is 4)' do
        ids = json['data'].map { |r| r.dig('attributes', 'quota_order_number_id') }
        expect(ids).to include('094011')
        expect(ids).not_to include('090011')
      end
    end
  end
end
