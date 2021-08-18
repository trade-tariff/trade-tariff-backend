describe Api::Admin::RollbacksController, 'POST to #create' do
  render_views

  before { login_as_api_user }

  let(:rollback_attributes) { attributes_for :rollback }
  let(:record) do
    create :measure, operation_date: Date.yesterday.to_date
  end

  context 'when rollback is valid' do
    before { record }

    it 'responds with success + redirect' do
      post :create, params: { data: { type: :rollback, attributes: rollback_attributes } }

      expect(response.status).to eq 201
      expect(response.location).to eq api_rollbacks_url
    end

    it 'performs a rollback' do
      Sidekiq::Testing.inline! do
        expect {
          create(:rollback, date: Date.current.ago(1.month).to_date)
        }.to change(Measure, :count).from(1).to(0)
      end
    end
  end

  context 'when rollback is not valid' do
    let(:response_pattern) do
      {
        errors: Array,
      }.ignore_extra_keys!
    end

    it 'returns errors for rollback' do
      post :create, params: { data: { type: :rollback, attributes: { date: '', keep: '' } } }

      expect(response.status).to eq 422
      expect(response.body).to match_json_expression response_pattern
    end
  end
end

describe Api::Admin::RollbacksController, 'GET to #index' do
  render_views

  before do
    login_as_api_user
  end

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

  it 'returns scheduled rollbacks' do
    get :index, format: :json

    expect(response.status).to eq 200
    expect(response.body).to match_json_expression response_pattern
  end

  context 'when records are not present' do
    before do
      rollback.delete
    end

    it 'returns empty rollbacks array' do
      get :index, format: :json

      expect(response.status).to eq 200
      expect(JSON.parse(response.body)['data']).to eq []
    end
  end
end
