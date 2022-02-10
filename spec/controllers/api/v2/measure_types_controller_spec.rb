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
end
