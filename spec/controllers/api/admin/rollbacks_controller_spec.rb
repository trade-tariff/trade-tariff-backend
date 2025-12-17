RSpec.describe Api::Admin::RollbacksController do
  routes { AdminApi.routes }

  describe 'POST to #create' do
    let(:rollback_attributes) { attributes_for :rollback }
    let(:record) do
      create :measure, operation_date: Time.zone.yesterday.to_date
    end

    context 'when rollback is valid' do
      before { record }

      it 'responds with success + redirect', :aggregate_failures do
        expect {
          post :create, params: { data: { type: :rollback, attributes: rollback_attributes } }
        }.to change(Rollback, :count).by(1)
        expect(response.status).to eq 201
        expect(response.location).to eq api_rollbacks_url
      end
    end

    context 'when rollback is not valid' do
      let(:response_pattern) do
        {
          errors: Array,
        }.ignore_extra_keys!
      end

      it 'returns errors for rollback', :aggregate_failures do
        post :create, params: { data: { type: :rollback, attributes: { date: '', keep: '' } } }

        expect(response.status).to eq 422
        expect(response.body).to match_json_expression response_pattern
      end
    end
  end

  describe 'GET to #index' do
    let!(:rollback) { create :rollback }

    let(:response_pattern) do
      {
        data: [
          {
            id: rollback.id.to_s,
            type: 'rollback',
            attributes: {
              user_id: rollback.user_id,
              reason: rollback.reason,
              enqueued_at: wildcard_matcher,
              date: rollback.date.to_s,
              keep: rollback.keep,
            },
          }.ignore_extra_keys!,
        ].ignore_extra_values!,
        meta: {
          pagination: {
            page: Integer,
            per_page: Integer,
            total_count: Integer,
          },
        },
      }
    end

    it 'returns scheduled rollbacks', :aggregate_failures do
      get :index, format: :json

      expect(response.status).to eq 200
      expect(response.body).to match_json_expression response_pattern
    end

    context 'when records are not present' do
      before do
        rollback.delete
      end

      it 'returns empty rollbacks array', :aggregate_failures do
        get :index, format: :json

        expect(response.status).to eq 200
        expect(JSON.parse(response.body)['data']).to eq []
      end
    end
  end
end
