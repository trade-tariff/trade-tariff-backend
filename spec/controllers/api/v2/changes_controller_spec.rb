RSpec.describe Api::V2::ChangesController do
  routes { V2Api.routes }

  let(:no_changes_response) { { 'data' => [] } }
  let(:goods_nomenclature_item_id) { nil }
  let(:goods_nomenclature_sid) { nil }
  let(:productline_suffix) { nil }
  let(:end_line) { nil }
  let(:change_type) { nil }
  let(:change_date) { Time.zone.today.strftime('%Y-%m-%d') }

  let(:expected_change_response) do
    {
      'data' => [{
        'id' => goods_nomenclature_sid.to_s,
        'type' => 'change',
        'attributes' => {
          'goods_nomenclature_item_id' => goods_nomenclature_item_id,
          'goods_nomenclature_sid' => goods_nomenclature_sid,
          'productline_suffix' => productline_suffix,
          'end_line' => end_line,
          'change_date' => change_date,
          'change_type' => change_type,
        },
      }],

    }
  end

  describe '#index' do
    it 'is successful' do
      get :index, format: :json

      expect(response).to be_successful
    end

    context 'when nothing has changed' do
      before { get :index, format: :json }

      let(:json) { JSON.parse(response.body) }

      it 'returns an empty array' do
        expect(json).to eq(no_changes_response)
      end
    end

    context 'when a commodity change exists for the day' do
      let!(:change) { create :change, change_date: Time.zone.today }
      let(:goods_nomenclature_item_id) { change.goods_nomenclature_item_id }
      let(:goods_nomenclature_sid) { change.goods_nomenclature_sid }
      let(:productline_suffix) { change.productline_suffix }
      let(:change_type) { 'commodity' }
      let(:end_line) { true }

      context 'when on the same day' do
        before { get :index, format: :json }

        let(:json) { JSON.parse(response.body) }

        it 'returns the correct code' do
          expect(json).to eq(expected_change_response)
        end
      end

      context 'when on the previous day' do
        before { get :index, params: { as_of: (Time.zone.today - 1.day) }, format: :json }

        let(:json) { JSON.parse(response.body) }

        it 'returns the expired code' do
          expect(json).to eq(no_changes_response)
        end
      end
    end

    context 'when a measure change exists for the day' do
      let!(:change) { create :change_measure, change_date: Time.zone.today }
      let(:goods_nomenclature_item_id) { change.goods_nomenclature_item_id }
      let(:goods_nomenclature_sid) { change.goods_nomenclature_sid }
      let(:productline_suffix) { change.productline_suffix }
      let(:change_type) { 'measure' }
      let(:end_line) { true }

      context 'when on the same day' do
        before { get :index, format: :json }

        let(:json) { JSON.parse(response.body) }

        it 'returns the correct code' do
          expect(json).to eq(expected_change_response)
        end
      end

      context 'when on the previous day' do
        before { get :index, params: { as_of: (Time.zone.today - 1.day) }, format: :json }

        let(:json) { JSON.parse(response.body) }

        it 'returns the expired code' do
          expect(json).to eq(no_changes_response)
        end
      end
    end
  end
end
