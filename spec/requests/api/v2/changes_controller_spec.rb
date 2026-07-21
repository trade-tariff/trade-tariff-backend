RSpec.describe Api::V2::ChangesController do
  def expected_change_response(change, change_type)
    {
      'data' => [{
        'id' => change.goods_nomenclature_sid.to_s,
        'type' => 'change',
        'attributes' => {
          'goods_nomenclature_item_id' => change.goods_nomenclature_item_id,
          'goods_nomenclature_sid' => change.goods_nomenclature_sid,
          'productline_suffix' => change.productline_suffix,
          'end_line' => true,
          'change_date' => Time.zone.today.strftime('%Y-%m-%d'),
          'change_type' => change_type,
        },
      }],
    }
  end

  describe '#index' do
    it 'is successful' do
      get '/uk/api/changes.json', headers: request_headers(format: :json)

      expect(response).to be_successful
    end

    context 'when nothing has changed' do
      before { get '/uk/api/changes.json', headers: request_headers(format: :json) }

      let(:json) { JSON.parse(response.body) }

      it 'returns an empty array' do
        expect(json).to eq('data' => [])
      end
    end

    context 'when a commodity change exists for the day' do
      let!(:change) { create :change, change_date: Time.zone.today }

      context 'when on the same day' do
        before { get '/uk/api/changes.json', headers: request_headers(format: :json) }

        let(:json) { JSON.parse(response.body) }

        it 'returns the correct code' do
          expect(json).to eq(expected_change_response(change, 'commodity'))
        end
      end

      context 'when on the previous day' do
        before { get "/uk/api/changes/#{Time.zone.today - 1.day}.json", headers: request_headers(format: :json) }

        let(:json) { JSON.parse(response.body) }

        it 'returns the expired code' do
          expect(json).to eq('data' => [])
        end
      end
    end

    context 'when a measure change exists for the day' do
      let!(:change) { create :change_measure, change_date: Time.zone.today }

      context 'when on the same day' do
        before { get '/uk/api/changes.json', headers: request_headers(format: :json) }

        let(:json) { JSON.parse(response.body) }

        it 'returns the correct code' do
          expect(json).to eq(expected_change_response(change, 'measure'))
        end
      end

      context 'when on the previous day' do
        before { get "/uk/api/changes/#{Time.zone.today - 1.day}.json", headers: request_headers(format: :json) }

        let(:json) { JSON.parse(response.body) }

        it 'returns the expired code' do
          expect(json).to eq('data' => [])
        end
      end
    end
  end
end
