RSpec.describe Api::User::GroupedMeasureChangesController do
  routes { UserApi.routes }

  let(:user_token) { 'Bearer tariff-api-test-token' }
  let(:user_id) { 'user123' }
  let(:user) { create(:public_user, external_id: user_id) }
  let(:user_hash) { { 'sub' => user_id, 'email' => 'test@example.com' } }

  before do
    request.headers['Authorization'] = user_token
    allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(user_hash)
    allow(Api::User::GroupedMeasureChangesService).to receive(:new).and_return(measure_changes_service)
    allow(measure_changes_service).to receive(:call).and_return(expected_response)
  end

  describe '#index' do
    let(:measure_changes_service) { instance_double(Api::User::GroupedMeasureChangesService) }
    let(:geographical_area) { create(:geographical_area, :with_description, geographical_area_id: 'GB') }
    let(:excluded_area_1) { create(:geographical_area, :with_description, geographical_area_id: 'FR') }
    let(:excluded_area_2) { create(:geographical_area, :with_description, geographical_area_id: 'DE') }
    let(:grouped_measure_change) do
      TariffChanges::GroupedMeasureChange.new(
        trade_direction: 'import',
        count: 5,
        geographical_area_id: 'GB',
        excluded_geographical_area_ids: %w[FR DE],
      )
    end
    let(:expected_response) { [grouped_measure_change] }

    context 'when authenticated' do
      before { get :index }

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'calls the MeasureChangesService with the current user' do
        expect(Api::User::GroupedMeasureChangesService).to have_received(:new).with(an_instance_of(PublicUsers::User), anything)
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
      before do
        request.headers['Authorization'] = nil
        get :index
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns proper error message' do
        expect(response.parsed_body).to eq({ 'message' => 'No bearer token was provided' })
      end
    end

    context 'when authentication fails' do
      before do
        allow(Api::User::UserService).to receive(:find_or_create).and_return(nil)
        get :index
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns proper error message' do
        expect(response.parsed_body).to eq({ 'message' => 'No bearer token was provided' })
      end
    end

    context 'when service returns different data structure' do
      let(:expected_response) { [] } # Empty array of GroupedMeasureChange objects

      before do
        allow(measure_changes_service).to receive(:call).and_return(expected_response)
        get :index
      end

      it 'returns the service response serialized' do
        expect(response.parsed_body['data']).to eq([])
      end
    end

    context 'when service raises an error' do
      before do
        allow(measure_changes_service).to receive(:call).and_raise(StandardError, 'Service error')
      end

      it 'allows the error to bubble up' do
        expect { get :index }.to raise_error(StandardError, 'Service error')
      end
    end
  end
end
