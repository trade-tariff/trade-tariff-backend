RSpec.describe Api::V2::MeasureTypesController, type: :request do
  describe '#index' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      get '/uk/api/measure_types', headers: request_headers
    end
    let(:json_body) { JSON.parse(api_response.body)['data'] }
    let(:validity_end_date) { nil }

    before do
      create(:measure_type, :with_measure_type_series_description, validity_end_date:)

      allow(TimeMachine).to receive(:at).and_call_original
    end

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
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get "/uk/api/measure_types/#{measure_type.id}.json", headers: request_headers(format: :json)
      end

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

      it { expect(api_response.body).to match_json_expression pattern }

      it { is_expected.to have_http_status :success }
    end

    context 'when records are not present' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get '/uk/api/measure_types/foo.json', headers: request_headers(format: :json)
      end

      let(:pattern) do
        {
          error: 'not found',
          url: 'http://www.example.com/uk/api/measure_types/foo.json',
        }
      end

      it { expect(api_response.body).to match_json_expression pattern }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
