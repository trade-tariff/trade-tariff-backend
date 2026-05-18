RSpec.describe Api::Admin::UpdatesController do
  describe 'GET #index' do
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
        ],
        meta: {
          pagination: {
            page: Integer,
            per_page: Integer,
            total_count: Integer,
          },
        },
      }
    end

    context 'when records are present' do
      before { create :taric_update }

      it 'returns api_response records' do
        get '/uk/admin/updates.json', headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when records are not present' do
      it 'returns blank array' do
        get '/uk/admin/updates.json', headers: request_headers(format: :json)

        expect(JSON.parse(response.body)['data']).to eq []
      end
    end
  end

  describe 'GET #show' do
    context 'when records are present' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get "/uk/admin/updates/#{update.to_param}.json", headers: request_headers(format: :json)
      end

      let(:pattern) do
        {
          data: {
            id: String,
            type: 'tariff_update',
            attributes: {
              update_type: 'TariffSynchronizer::CdsUpdate',
              state: String,
              filename: String,
              created_at: String,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
        }
      end

      let(:update) { create(:cds_update) }

      it { expect(api_response.body).to match_json_expression pattern }
    end

    context 'when records are not present' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get '/uk/admin/updates/foo.json', headers: request_headers(format: :json)
      end

      let(:pattern) do
        {
          error: 'not found',
          url: 'http://www.example.com/uk/admin/updates/foo.json',
        }
      end

      it { expect(api_response.body).to match_json_expression pattern }
    end
  end
end
