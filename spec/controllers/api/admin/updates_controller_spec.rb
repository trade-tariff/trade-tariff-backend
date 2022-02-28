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

      it 'returns rendered records' do
        get :index, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when records are not present' do
      it 'returns blank array' do
        get :index, format: :json

        expect(JSON.parse(response.body)['data']).to eq []
      end
    end
  end
end
