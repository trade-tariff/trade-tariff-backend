RSpec.describe Api::Admin::UpdatesController do
  routes { AdminApi.routes }

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

  describe 'GET #show' do
    context 'when records are present' do
      subject(:do_request) { get :show, params: { id: update.to_param, format: :json } }

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

      it { expect(do_request.body).to match_json_expression pattern }
    end

    context 'when records are not present' do
      subject(:do_request) { get :show, params: { id: 'foo', format: :json } }

      let(:pattern) do
        {
          error: 'not found',
          url: 'http://test.host/admin/updates/foo',
        }
      end

      it { expect(do_request.body).to match_json_expression pattern }
    end
  end
end
