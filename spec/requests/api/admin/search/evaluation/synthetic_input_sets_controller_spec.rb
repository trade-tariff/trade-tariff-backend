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

  describe 'GET #show' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_synthetic_input_set_path(synthetic_input_set.id, format: :json) }
    let(:synthetic_input_set) { create(:evaluation_synthetic_input_set, name: 'Set A', requested_size: 5, actual_size: 3, created_by: 'operator-1') }

    before { create(:evaluation_synthetic_input_set_item, evaluation_synthetic_input_set: synthetic_input_set) }

    it { is_expected.to have_http_status :ok }

    it 'returns the set without its items, which have their own paginated endpoint' do
      expect(json_response['data']['id']).to eq(synthetic_input_set.id.to_s)
      expect(json_response['data']['type']).to eq('synthetic_input_set')
      expect(json_response['data']['attributes']).to include('name' => 'Set A', 'requested_size' => 5, 'actual_size' => 3, 'created_by' => 'operator-1')
      expect(json_response['data']['attributes']).not_to have_key('items')
    end

    context 'when the set does not exist' do
      let(:make_request) { authenticated_get api_admin_search_evaluation_synthetic_input_set_path(0, format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'DELETE #destroy' do
    let(:make_request) { authenticated_delete api_admin_search_evaluation_synthetic_input_set_path(synthetic_input_set.id, format: :json) }
    let!(:synthetic_input_set) { create(:evaluation_synthetic_input_set) }

    before { create_list(:evaluation_synthetic_input_set_item, 2, evaluation_synthetic_input_set: synthetic_input_set) }

    it { is_expected.to have_http_status :no_content }

    it 'deletes the set and its items' do
      expect { api_response }
        .to change(EvaluationSyntheticInputSet, :count).by(-1)
        .and change(EvaluationSyntheticInputSetItem, :count).by(-2)
    end

    context 'when an experiment uses the set' do
      before do
        create(:evaluation_experiment, name: 'baseline', synthetic_input_set_id: synthetic_input_set.id)
        create(:evaluation_experiment, name: 'with-rerank', synthetic_input_set_id: synthetic_input_set.id)
      end

      it { is_expected.to have_http_status :conflict }
      it { expect { api_response }.not_to change(EvaluationSyntheticInputSet, :count) }
      it { expect { api_response }.not_to change(EvaluationSyntheticInputSetItem, :count) }

      it 'names the experiments so the operator knows what to change' do
        expect(json_response['errors'].first).to include('status' => '409', 'title' => 'Synthetic input set is in use')
        expect(json_response['errors'].first['detail']).to include('baseline', 'with-rerank')
      end

      it 'tells the operator to delete the experiments, because an experiment cannot be moved to another set' do
        detail = json_response['errors'].first['detail']

        expect(detail).to include('delete those experiments first', 'runs and results')
        expect(detail).not_to include('another set')
      end
    end

    context 'when an experiment starts using the set after the check but before the delete' do
      before do
        set = EvaluationSyntheticInputSet.with_pk!(synthetic_input_set.id)
        allow(set).to receive(:destroy) do
          create(:evaluation_experiment, name: 'raced', synthetic_input_set_id: set.id)
          raise Sequel::ForeignKeyConstraintViolation
        end
        allow(EvaluationSyntheticInputSet).to receive(:with_pk!).and_return(set)
      end

      it { is_expected.to have_http_status :conflict }

      it 'names the experiment that got there first' do
        expect(json_response['errors'].first['detail']).to include('raced')
      end
    end

    context 'when an experiment uses a different set' do
      before { create(:evaluation_experiment, synthetic_input_set_id: create(:evaluation_synthetic_input_set).id) }

      it { is_expected.to have_http_status :no_content }
    end

    context 'when the set does not exist' do
      let(:make_request) { authenticated_delete api_admin_search_evaluation_synthetic_input_set_path(0, format: :json) }

      it { is_expected.to have_http_status :not_found }
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
