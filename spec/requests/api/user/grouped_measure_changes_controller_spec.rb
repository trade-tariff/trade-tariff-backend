RSpec.describe Api::User::GroupedMeasureChangesController do
  include_context 'with user API authentication'

  before do
    allow(Api::User::GroupedMeasureChangesService).to receive(:new).and_return(measure_changes_service)
  end

  describe '#index' do
    let(:measure_changes_service) do
      instance_double(Api::User::GroupedMeasureChangesService, call: [grouped_measure_change])
    end
    let(:grouped_measure_change) do
      TariffChanges::GroupedMeasureChange.new(
        trade_direction: 'import',
        count: 5,
        geographical_area_id: 'GB',
        excluded_geographical_area_ids: %w[FR DE],
      )
    end

    before do
      create(:geographical_area, :with_description, geographical_area_id: 'GB')
      create(:geographical_area, :with_description, geographical_area_id: 'FR')
      create(:geographical_area, :with_description, geographical_area_id: 'DE')
    end

    context 'when authenticated' do
      before { get '/uk/user/grouped_measure_changes', headers: request_headers }

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'calls the MeasureChangesService with the current user' do
        expect(Api::User::GroupedMeasureChangesService).to have_received(:new).with(
          an_instance_of(PublicUsers::User),
          nil,
          Time.zone.yesterday,
        )
        expect(measure_changes_service).to have_received(:call)
      end

      it 'returns tariff changes data in the expected JSON API format' do
        response_body = response.parsed_body

        expect(response_body).to have_key('data')
        expect(response_body['data']).to be_an(Array)
        expect(response_body['data'].length).to eq(1)

        first_item = response_body['data'].first
        expect(first_item).to include(
          'type' => 'grouped_measure_change',
          'attributes' => {
            'trade_direction' => 'import',
            'count' => 5,
          },
        )
        expect(first_item).to have_key('relationships')
      end
    end

    context 'when not authenticated' do
      let(:request_header_overrides) { {} }

      before do
        get '/uk/user/grouped_measure_changes', headers: request_headers
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns proper error message' do
        expect(response.parsed_body).to eq({ 'errors' => [{ 'code' => 'missing_token', 'detail' => 'No bearer token was provided' }] })
      end
    end

    context 'when authentication fails' do
      before do
        allow(Api::User::UserService).to receive(:find).and_return(
          CognitoTokenVerifier::Result.new(valid: false, payload: nil, reason: :expired),
        )
        get '/uk/user/grouped_measure_changes', headers: request_headers
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns proper error message' do
        expect(response.parsed_body).to eq({ 'errors' => [{ 'code' => 'expired', 'detail' => 'Token has expired' }] })
      end
    end

    context 'when service returns different data structure' do
      before do
        allow(measure_changes_service).to receive(:call).and_return([])
        get '/uk/user/grouped_measure_changes', headers: request_headers
      end

      it 'returns the service response serialized' do
        expect(response.parsed_body['data']).to eq([])
      end
    end

    context 'when service raises an error' do
      before do
        allow(measure_changes_service).to receive(:call).and_raise(StandardError, 'Service error')
      end

      it 'returns an internal server error' do
        get '/uk/user/grouped_measure_changes', headers: request_headers

        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'with pagination parameters' do
      before { get '/uk/user/grouped_measure_changes', params: { page: 2, per_page: 10 }, headers: request_headers }

      it 'passes pagination parameters to the service' do
        expect(measure_changes_service).to have_received(:call).with(page: 2, per_page: 10)
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without pagination parameters' do
      before { get '/uk/user/grouped_measure_changes', headers: request_headers }

      it 'passes default pagination parameters to the service' do
        expect(measure_changes_service).to have_received(:call).with(page: 1, per_page: 20)
      end
    end
  end

  describe '#show' do
    let(:measure_changes_service) do
      instance_double(Api::User::GroupedMeasureChangesService, call: grouped_measure_change)
    end
    let(:id) { 'import_GB_FR-DE' }

    let(:grouped_measure_change) do
      TariffChanges::GroupedMeasureChange.new(
        trade_direction: 'import',
        count: 5,
        geographical_area_id: 'GB',
        excluded_geographical_area_ids: %w[FR DE],
        commodities: [
          { goods_nomenclature_item_id: '1234567890', count: 3 },
          { goods_nomenclature_item_id: '9876543210', count: 2 },
        ],
      )
    end

    context 'when authenticated and id is provided' do
      before { get "/uk/user/grouped_measure_changes/#{id}", headers: request_headers }

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'calls the GroupedMeasureChangesService with user, id and as_of date' do
        expect(Api::User::GroupedMeasureChangesService).to have_received(:new).with(
          an_instance_of(PublicUsers::User),
          id,
          Time.zone.yesterday,
        )
        expect(measure_changes_service).to have_received(:call)
      end

      it 'returns tariff changes data with commodity changes in JSON API format' do
        response_body = response.parsed_body

        expect(response_body).to have_key('data')
        expect(response_body['data']).to be_a(Hash)
        expect(response_body['data']).to include(
          'type' => 'grouped_measure_change',
          'attributes' => {
            'trade_direction' => 'import',
            'count' => 5,
          },
        )
        expect(response_body['data']).to have_key('relationships')
      end
    end

    context 'when custom as_of date is provided' do
      before { get "/uk/user/grouped_measure_changes/#{id}", params: { as_of: '2024-01-15' }, headers: request_headers }

      it 'calls the service with the custom as_of date' do
        expect(Api::User::GroupedMeasureChangesService).to have_received(:new).with(
          an_instance_of(PublicUsers::User),
          id,
          Date.parse('2024-01-15'),
        )
      end
    end

    context 'when not authenticated' do
      let(:request_header_overrides) { {} }

      before do
        get "/uk/user/grouped_measure_changes/#{id}", headers: request_headers
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns proper error message' do
        expect(response.parsed_body).to eq({ 'errors' => [{ 'code' => 'missing_token', 'detail' => 'No bearer token was provided' }] })
      end
    end

    context 'when service raises an error' do
      before do
        allow(measure_changes_service).to receive(:call).and_raise(StandardError, 'Service error')
      end

      it 'returns an internal server error' do
        get "/uk/user/grouped_measure_changes/#{id}", headers: request_headers

        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'with pagination parameters' do
      before { get "/uk/user/grouped_measure_changes/#{id}", params: { page: 3, per_page: 20 }, headers: request_headers }

      it 'passes pagination parameters to the service' do
        expect(measure_changes_service).to have_received(:call).with(page: 3, per_page: 20)
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without pagination parameters' do
      before { get "/uk/user/grouped_measure_changes/#{id}", headers: request_headers }

      it 'passes default pagination parameters to the service' do
        expect(measure_changes_service).to have_received(:call).with(page: 1, per_page: 20)
      end
    end
  end
end
