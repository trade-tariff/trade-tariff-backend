require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::SyntheticInputSetsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }

  describe 'GET #index' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_synthetic_input_sets_path(format: :json), params: }
    let(:params) { {} }

    let!(:older_set) { create(:evaluation_synthetic_input_set, name: 'Older set', created_at: 2.days.ago) }
    let!(:newer_set) { create(:evaluation_synthetic_input_set, name: 'Newer set', created_at: 1.day.ago) }

    it { is_expected.to have_http_status :ok }

    it 'lists every set, newest first, for the experiment picker to choose from' do
      expect(json_response['data'].pluck('id')).to eq([newer_set.id.to_s, older_set.id.to_s])
      expect(json_response['data'].first['attributes']).to include('name' => 'Newer set')
    end

    it 'paginates like the gold query sets index does' do
      params[:per_page] = 1

      expect(json_response.dig('meta', 'pagination')).to eq('page' => 1, 'per_page' => 1, 'total_count' => 2)
    end

    it 'does not serialize items, which the picker never reads, to avoid a query per set plus a large response' do
      expect(json_response['data']).to all(satisfy { |row| !row['attributes'].key?('items') })
    end
  end

  describe 'POST #create' do
    let(:make_request) { authenticated_post api_admin_search_evaluation_synthetic_input_sets_path(format: :json), params:, headers: }
    let(:headers) { { 'X-Whodunnit' => 'operator-1' } }
    let(:attributes) { { name: 'Set A', requested_size: 3 } }
    let(:params) { { data: { type: :synthetic_input_set, attributes: } } }

    before { create_list(:tariff_knowledge_synthetic_atar, 3) }

    context 'with valid params' do
      it { is_expected.to have_http_status :created }
      it { expect { api_response }.to change(EvaluationSyntheticInputSet, :count).by(1) }

      it 'returns the set and its items' do
        expect(json_response['data']['type']).to eq('synthetic_input_set')
        expect(json_response['data']['attributes']).to include('name' => 'Set A', 'requested_size' => 3, 'actual_size' => 3, 'created_by' => 'operator-1')
        items = json_response['data']['attributes']['items']
        expect(items.size).to eq(3)
        expect(items.first.keys).to include('id', 'synthetic_atar_id', 'query', 'expected_code')
      end
    end

    context 'when the body tries to set created_by directly' do
      let(:attributes) { { name: 'Set A', requested_size: 3, created_by: 'spoofed-user' } }

      it 'ignores it, taking created_by from the header instead' do
        expect(json_response['data']['attributes']['created_by']).to eq('operator-1')
      end
    end

    context 'with a missing name' do
      let(:attributes) { { requested_size: 3 } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect { api_response }.not_to change(EvaluationSyntheticInputSet, :count) }
      it { expect(json_response['errors'].first['source']['pointer']).to eq('/data/attributes/name') }
    end

    context 'when requested_size is more than the number of synthetic ATaRs that exist' do
      let(:attributes) { { name: 'Set A', requested_size: 999 } }

      it { is_expected.to have_http_status :created }
      it { expect(json_response['data']['attributes']).to include('requested_size' => 999, 'actual_size' => 3) }
    end

    context 'with a name that is already used' do
      before { create(:evaluation_synthetic_input_set, name: 'Set A') }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response['errors'].first['title']).to eq('is already taken') }
    end
  end
end
