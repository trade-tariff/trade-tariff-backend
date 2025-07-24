RSpec.describe Api::V2::MeasuresController, :v2 do
  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    let(:measure) { create(:measure) }

    let :make_request do
      get api_measure_path(id: measure.measure_sid, format: :json)
    end

    it_behaves_like 'a successful jsonapi response'

    context 'for historical measure' do
      let(:measure) { create(:measure, validity_end_date: 2.days.ago) }

      it { is_expected.to have_http_status :not_found }
    end

    context 'for negative measure' do
      let(:measure) { create(:measure, measure_sid: -2000) }

      it_behaves_like 'a successful jsonapi response'
    end
  end
end
