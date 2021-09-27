RSpec.describe Api::Admin::FootnotesController, 'GET to #index' do
  let!(:non_national_footnote) { create :footnote, :non_national }
  let(:response_pattern) do
    {
      data: [{
        id: String,
        type: String,
        attributes: {
          footnote_id: String,
          footnote_type_id: String,
          validity_start_date: String,
          description: String,
        }.ignore_extra_keys!,
      }],
    }
  end
  let(:json_body) do
    JSON.parse(response.body)['data']
  end
  let!(:national_footnote) { create :footnote, :national }

  before { login_as_api_user }

  specify 'returns national footnote' do
    get :index, format: :json

    expect(response.body).to match_json_expression response_pattern
    expect(json_body.map { |f| f['id'] }).to include national_footnote.pk.join
  end

  specify 'does not return non-national footnote' do
    get :index, format: :json

    expect(json_body.map { |f| f['id'] }).not_to include non_national_footnote.pk.join
  end
end

RSpec.describe Api::Admin::FootnotesController, 'GET to #show' do
  before { login_as_api_user }

  let!(:non_national_footnote) { create :footnote, :non_national }
  let!(:national_footnote)     { create :footnote, :national }

  let(:response_pattern) do
    {
      data: {
        id: String,
        type: String,
        attributes: {
          footnote_id: String,
          footnote_type_id: String,
          validity_start_date: String,
          description: String,
        }.ignore_extra_keys!,
      },
    }
  end

  specify 'returns national footnote' do
    get :show, params: { id: national_footnote.pk.join }, format: :json

    expect(response.body).to match_json_expression response_pattern
  end

  specify 'does not return non-national footnote' do
    get :show, params: { id: non_national_footnote.pk.join }, format: :json

    expect(response.status).to eq 404
  end
end

RSpec.describe Api::Admin::FootnotesController, 'PUT to #update' do
  before { login_as_api_user }

  let!(:non_national_footnote) { create :footnote, :non_national }
  let!(:national_footnote)     { create :footnote, :national }

  specify 'updates national footnote' do
    expect {
      put :update, params: { id: national_footnote.pk.join, data: { type: :footnote, attributes: { description: 'new description' } } }, format: :json
    }.to change { national_footnote.reload.description }.to('new description')
  end

  specify 'does not update non-national footnote' do
    put :update, params: { id: non_national_footnote.pk.join, data: {} }, format: :json

    expect(response.status).to eq 404
  end
end
