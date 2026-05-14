RSpec.describe Api::V2::UpdatesController do
  describe 'GET #latest' do
    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'tariff_update',
            attributes: {
              update_type: 'TariffSynchronizer::TaricUpdate',
              state: String,
              filename: String,
              created_at: String,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
        ].ignore_extra_values!,
      }
    end

    context 'when records are present' do
      it 'returns api_response records' do
        create :taric_update, :applied

        get '/uk/api/updates/latest.json', headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when records are not present' do
      it 'returns blank array' do
        get '/uk/api/updates/latest.json', headers: request_headers(format: :json)

        expect(
          JSON.parse(response.body)['data'],
        ).to eq []
      end
    end
  end
end
