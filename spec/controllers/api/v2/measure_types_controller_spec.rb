RSpec.describe Api::V2::MeasureTypesController, type: :controller do
  routes { V2Api.routes }

  describe '#index' do
    subject(:do_request) { get :index }

    before do
      create(:measure_type, :with_measure_type_series_description, validity_end_date:)

      allow(TimeMachine).to receive(:at).and_call_original
    end

    let(:json_body) { JSON.parse(do_request.body)['data'] }

    let(:validity_end_date) { nil }

    it { is_expected.to have_http_status(:success) }

    it 'returns all measure types' do
      expect(json_body.length).to eq 1
    end

    context 'when the validity_end_date is set to a past date' do
      let(:validity_end_date) { 1.day.ago }

      it { expect(json_body).to eq [] }
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
          url: 'http://test.host/uk/api/measure_types/foo',
        }
      end

      it { expect(do_request.body).to match_json_expression pattern }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
