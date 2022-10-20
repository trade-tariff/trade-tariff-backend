RSpec.describe Api::V2::MeasureTypesController, type: :controller do
  describe '#index' do
    before do
      create(:measure_type, :with_measure_type_series_description)

      allow(TimeMachine).to receive(:at).and_call_original
    end

    it 'returns success' do
      get :index, format: :json

      expect(response).to be_successful
    end

    it 'returns all measure types' do
      get :index, format: :json

      data = JSON.parse(response.body)['data']

      expect(data.length).to eq 1
    end

    it 'the TimeMachine receives the correct Date' do
      get :index, format: :json

      expect(TimeMachine).to have_received(:at).with(Time.zone.today)
    end
  end

  describe 'GET #show' do
    context 'when records are present' do
      subject(:do_request) { get :show, params: { id: measure_type.id, format: :json } }

      let(:pattern) do
        {
          data: {
            id: String,
            type: 'measure_type',
            attributes: {
              description: String,
              measure_type_series_id: String,
              id: String,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
        }
      end

      let(:measure_type) { create(:measure_type, :with_measure_type_series_description) }

      it { expect(do_request.body).to match_json_expression pattern }

      it { is_expected.to have_http_status :success }
    end

    context 'when records are not present' do
      subject(:do_request) { get :show, params: { id: 'foo', format: :json } }

      let(:pattern) do
        {
          error: 'not found',
          url: 'http://test.host/measure_types/foo',
        }
      end

      it { expect(do_request.body).to match_json_expression pattern }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
