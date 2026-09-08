RSpec.describe Api::V2::MeasureTypesController, type: :request do
  let(:validity_end_date) { nil }

  let(:measure_type) do
    create(
      :measure_type,
      measure_type_id: '110',
      measure_type_series_id: 'C',
      validity_end_date:,
    )
  end

  describe '#index' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      get '/uk/api/measure_types', headers: request_headers
    end
    let(:json_body) { JSON.parse(api_response.body)['data'] }

    before do
      measure_type

      allow(TimeMachine).to receive(:at).and_call_original
    end

    it { is_expected.to have_http_status(:success) }

    it 'returns all measure types' do
      expect(json_body.length).to eq 1
    end

    it 'includes the semantic roles' do
      expect(json_body.first.fetch('attributes').fetch('semantic_roles'))
        .to contain_exactly('supplementary', 'supplementary_unit_import_only')
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

      let(:json_body) { JSON.parse(api_response.body).fetch('data') }

      it { expect(api_response.body).to match_json_expression pattern }

      it { is_expected.to have_http_status :success }

      it 'includes the semantic roles' do
        expect(json_body.fetch('attributes').fetch('semantic_roles'))
          .to contain_exactly('supplementary', 'supplementary_unit_import_only')
      end
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
          errors: [{ detail: 'not found' }],
        }
      end

      it { expect(api_response.body).to match_json_expression pattern }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
