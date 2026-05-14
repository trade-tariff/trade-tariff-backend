RSpec.describe Api::User::GroupedMeasureCommodityChangesController do
  include_context 'with user API authentication'

  let(:id) { 'import_GB_FR-DE_1234567890' }
  let(:change) { instance_double(TariffChanges::GroupedMeasureCommodityChange) }
  let(:serializer) { instance_double(Api::User::GroupedMeasureCommodityChangeSerializer, serializable_hash: { data: { id: id, type: 'grouped_measure_commodity_change' } }) }

  before do
    allow(TariffChanges::GroupedMeasureCommodityChange).to receive(:from_id).with(id).and_return(change)
    allow(Api::User::GroupedMeasureCommodityChangeSerializer)
      .to receive(:new)
      .and_return(serializer)
  end

  describe '#show' do
    context 'when authenticated' do
      before { get :show, params: { id: id } }

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'builds a change from the id' do
        expect(TariffChanges::GroupedMeasureCommodityChange).to have_received(:from_id).with(id).at_least(:once)
      end

      it 'serializes the change with include and date params' do
        expect(Api::User::GroupedMeasureCommodityChangeSerializer)
          .to have_received(:new)
          .with(
            change,
            hash_including(
              include: array_including(
                'commodity',
                'grouped_measure_change',
                'grouped_measure_change.geographical_area',
                'grouped_measure_change.excluded_countries',
              ),
              params: { date: Time.zone.yesterday.to_s },
            ),
          )
      end

      it 'returns serialized data' do
        expect(response.parsed_body).to eq({ 'data' => { 'id' => id, 'type' => 'grouped_measure_commodity_change' } })
      end
    end

    context 'when custom as_of date is provided' do
      let(:as_of) { '2024-01-15' }

      before { get :show, params: { id: id, as_of: as_of } }

      it 'passes the custom date to the serializer' do
        expect(Api::User::GroupedMeasureCommodityChangeSerializer)
          .to have_received(:new)
          .with(
            change,
            hash_including(
              params: { date: Date.parse(as_of).to_s },
            ),
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
        expect(response.parsed_body).to eq({ 'errors' => [{ 'code' => 'missing_token', 'detail' => 'No bearer token was provided' }] })
      end
    end
  end
end
