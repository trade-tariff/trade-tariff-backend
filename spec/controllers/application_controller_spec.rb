RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render(plain: actual_date.to_formatted_s(:db))
    end
  end

  describe 'handling invalid dates' do
    it 'overrides to today if date is out of range' do
      response = get :index, params: { as_of: '2023000-01-01' }
      expect(response.body).to eq(Time.zone.now.to_date.to_formatted_s(:db))
    end

    it 'respects the date if it is in range' do
      response = get :index, params: { as_of: '2024-01-01' }
      expect(response.body).to eq('2024-01-01')
    end
  end
end
