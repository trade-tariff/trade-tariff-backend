RSpec.describe Api::User::GroupedMeasureChangesController do
  include_context 'with user API authentication'

  before do
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
        expect(Api::User::GroupedMeasureChangesService).to have_received(:new).with(
          an_instance_of(PublicUsers::User),
          nil,
          Time.zone.yesterday.to_date.to_s,
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

  describe '#show' do
    let(:measure_changes_service) { instance_double(Api::User::GroupedMeasureChangesService) }
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
    let(:expected_response) { grouped_measure_change }

    context 'when authenticated and id is provided' do
      before { get :show, params: { id: id } }

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'calls the GroupedMeasureChangesService with user, id and as_of date' do
        expect(Api::User::GroupedMeasureChangesService).to have_received(:new).with(
          an_instance_of(PublicUsers::User),
          id,
          Time.zone.yesterday.to_date.to_s,
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
      let(:custom_date) { '2024-01-15' }

      before { get :show, params: { id: id, as_of: custom_date } }

      it 'calls the service with the custom as_of date' do
        expect(Api::User::GroupedMeasureChangesService).to have_received(:new).with(
          an_instance_of(PublicUsers::User),
          id,
          custom_date,
        )
      end
    end

    context 'when not authenticated' do
      before do
        request.headers['Authorization'] = nil
        get :show, params: { id: id }
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns proper error message' do
        expect(response.parsed_body).to eq({ 'message' => 'No bearer token was provided' })
      end
    end

    context 'when service returns nil' do
      let(:expected_response) { nil }

      before do
        allow(measure_changes_service).to receive(:call).and_return(expected_response)
        get :show, params: { id: id }
      end

      it 'returns the service response serialized (null)' do
        expect(response.parsed_body['data']).to be_nil
      end
    end

    context 'when service raises an error' do
      before do
        allow(measure_changes_service).to receive(:call).and_raise(StandardError, 'Service error')
      end

      it 'allows the error to bubble up' do
        expect { get :show, params: { id: id } }.to raise_error(StandardError, 'Service error')
      end
    end
  end
end
