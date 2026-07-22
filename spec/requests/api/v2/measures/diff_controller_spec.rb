RSpec.describe Api::V2::Measures::DiffController do
  describe 'GET #index' do
    subject(:do_request) do
      get '/uk/api/measures/diff', params:, headers: request_headers(format: :json)
    end

    let(:json) { JSON.parse(response.body) }

    context 'when from_date is missing' do
      let(:params) { { to_date: Time.zone.today.iso8601 } }

      before { do_request }

      it 'returns unprocessable content' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when to_date is before from_date' do
      let(:params) { { from_date: Time.zone.today.iso8601, to_date: (Time.zone.today - 1.day).iso8601 } }

      before { do_request }

      it 'returns bad request' do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with a valid date range and no operations' do
      let(:params) { { from_date: 7.days.ago.to_date.iso8601, to_date: Time.zone.today.iso8601 } }

      before { do_request }

      it 'is successful with empty data' do
        expect(response).to be_successful
        expect(json['data']).to eq([])
      end

      it 'includes date range in meta' do
        expect(json['meta']).to include(
          'from_date' => 7.days.ago.to_date.iso8601,
          'to_date' => Time.zone.today.iso8601,
        )
      end
    end

    context 'when measure operations exist in the range' do
      let(:from) { 7.days.ago.to_date }
      let(:params) { { from_date: from.iso8601, to_date: Time.zone.today.iso8601 } }

      before do
        Measure::Operation.insert(
          measure_sid: 90_000_001,
          goods_nomenclature_item_id: '0101210000',
          geographical_area_id: '1011',
          operation: 'C',
          operation_date: Date.current,
        )
        do_request
      end

      it 'returns operation records' do
        expect(json['data']).not_to be_empty
      end

      it 'includes operation attributes' do
        attrs = json['data'].first['attributes']
        expect(attrs).to have_key('measure_sid')
        expect(attrs).to have_key('operation')
        expect(attrs).to have_key('operation_date')
        expect(attrs).to have_key('goods_nomenclature_item_id')
        expect(attrs['operation']).to be_in(%w[created updated deleted])
      end

      it 'includes pagination in meta' do
        expect(json.dig('meta', 'pagination', 'total_count')).to be >= 1
      end
    end

    context 'when paginating results' do
      let(:from) { 7.days.ago.to_date }

      before do
        3.times do |i|
          Measure::Operation.insert(
            measure_sid: 90_000_010 + i,
            goods_nomenclature_item_id: '0101210000',
            operation: 'C',
            operation_date: Date.current,
          )
        end
        get '/uk/api/measures/diff',
            params: { from_date: from.iso8601, to_date: Time.zone.today.iso8601, per_page: 2, page: 1 },
            headers: request_headers(format: :json)
      end

      it 'respects per_page' do
        expect(json['data'].length).to eq(2)
      end

      it 'reports total_count' do
        expect(json.dig('meta', 'pagination', 'total_count')).to be >= 3
      end
    end
  end
end
