RSpec.describe Api::V2::QuotaOrderNumbers::UtilizationController do
  describe 'GET #show' do
    subject(:do_request) do
      get "/uk/api/quota_order_numbers/#{order_number_id}/utilization",
          params:,
          headers: request_headers(format: :json)
    end

    let(:json) { JSON.parse(response.body) }
    let(:params) { {} }

    context 'when the quota order number does not exist' do
      let(:order_number_id) { '999999' }

      before { do_request }

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the quota order number has an invalid format' do
      let(:order_number_id) { 'abc123' }

      before { do_request }

      it 'returns not found (constraint rejects the route)' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the quota order number exists with a definition' do
      let(:order_number_id) { '094011' }
      let(:initial_volume) { 10_000.0 }

      before do
        order_number = create(:quota_order_number, quota_order_number_id: order_number_id)
        create(:quota_definition,
               quota_order_number_id: order_number_id,
               quota_order_number_sid: order_number.quota_order_number_sid,
               initial_volume:)
        do_request
      end

      it 'is successful' do
        expect(response).to be_successful
      end

      it 'returns the quota order number id in meta' do
        expect(json.dig('meta', 'quota_order_number_id')).to eq(order_number_id)
      end

      it 'returns utilization data with zero utilization when no balance events exist' do
        record = json['data'].first
        expect(record['type']).to eq('quota_utilization')
        expect(record.dig('attributes', 'quota_order_number_id')).to eq(order_number_id)
        expect(record.dig('attributes', 'initial_volume')).to eq(initial_volume)
        expect(record.dig('attributes', 'utilization_percentage')).to eq(0.0)
      end
    end

    context 'when balance events exist in the requested range' do
      let(:order_number_id) { '094012' }
      let(:initial_volume) { 1000.0 }
      let(:params) do
        {
          from_date: Date.current.beginning_of_year.iso8601,
          to_date: Date.current.iso8601,
        }
      end

      before do
        order_number = create(:quota_order_number, quota_order_number_id: order_number_id)
        quota_definition = create(:quota_definition,
                                  quota_order_number_id: order_number_id,
                                  quota_order_number_sid: order_number.quota_order_number_sid,
                                  initial_volume:)
        create(:quota_balance_event,
               quota_definition_sid: quota_definition.quota_definition_sid,
               occurrence_timestamp: Date.current.beginning_of_year + 1.month,
               new_balance: 750.0)
        do_request
      end

      it 'is successful' do
        expect(response).to be_successful
      end

      it 'computes utilization from the last balance event and includes event summary' do
        attrs = json['data'].first['attributes']
        expect(attrs['current_balance']).to eq(750.0)
        expect(attrs['volume_used']).to eq(250.0)
        expect(attrs['utilization_percentage']).to eq(25.0)

        events = attrs['balance_event_summary']
        expect(events).not_to be_empty
        expect(events.first['new_balance']).to eq(750.0)
      end
    end
  end
end
