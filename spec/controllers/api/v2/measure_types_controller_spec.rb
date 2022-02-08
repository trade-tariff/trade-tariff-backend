RSpec.describe Api::V2::MeasureTypesController, type: :controller do
  describe '#index' do
    before do
      create(:measure_type, :with_measure_type_series_description)
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
  end
end
