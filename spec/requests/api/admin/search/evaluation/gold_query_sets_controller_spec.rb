require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::GoldQuerySetsController, :admin do
  include GoldQueryItemHelper

  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }

  describe 'GET #index' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_gold_query_sets_path(format: :json, **query) }
    let(:query) { {} }

    let(:older_set) { create(:evaluation_gold_query_set, name: 'Older set', created_at: 2.days.ago) }

    before do
      create(:evaluation_gold_query_set, name: 'Newer set', created_at: 1.day.ago)
      create_gold_query_item(older_set, source_type: 'atar', source_id: '600000001')
      create_gold_query_item(older_set, source_type: 'synthetic_atar', source_id: '7')
      create_gold_query_item(older_set, source_type: 'synthetic_atar', source_id: '8')
    end

    it { is_expected.to have_http_status :ok }

    it 'lists the newest set first' do
      expect(json_response['data'].map { |row| row['attributes']['name'] }).to eq(['Newer set', 'Older set'])
    end

    it 'says how many items each set holds now, by source type' do
      counts = json_response['data'].to_h { |row| [row['attributes']['name'], row['attributes'].slice('atar_count', 'synthetic_atar_count')] }

      expect(counts).to eq(
        'Older set' => { 'atar_count' => 1, 'synthetic_atar_count' => 2 },
        'Newer set' => { 'atar_count' => 0, 'synthetic_atar_count' => 0 },
      )
    end

    it 'includes the real total number of gold queries, one per persona per item, not the deduplicated item count' do
      counts = json_response['data'].to_h { |row| [row['attributes']['name'], row['attributes']['gold_query_count']] }

      expect(counts).to eq('Older set' => 9, 'Newer set' => 0)
    end

    it 'includes the progress counters and the failures' do
      expect(json_response['data'].first['attributes']).to include('status', 'planned_count', 'generated_count', 'failed_count', 'failures')
    end

    it 'includes pagination meta' do
      expect(json_response.dig('meta', 'pagination')).to include('page' => 1, 'per_page' => 20, 'total_count' => 2)
    end

    context 'when asking for the second page of one' do
      let(:query) { { page: 2, per_page: 1 } }

      it 'returns the older set' do
        expect(json_response['data'].map { |row| row['attributes']['name'] }).to eq(['Older set'])
      end
    end
  end

  describe 'GET #show' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_gold_query_set_path(gold_query_set.id, format: :json) }
    let(:gold_query_set) { create(:evaluation_gold_query_set, failed_count: 1, failures: [{ 'source_type' => 'atar', 'source_id' => '600000009', 'error' => 'the model did not return acceptable phrases after 3 attempts' }].to_json) }

    before { create_gold_query_item(gold_query_set, source_type: 'atar', source_id: '600000001') }

    it { is_expected.to have_http_status :ok }

    it 'returns the set with its item counts and failures' do
      expect(json_response['data']['id']).to eq(gold_query_set.id.to_s)
      expect(json_response['data']['attributes']).to include(
        'name' => gold_query_set.name,
        'atar_count' => 1,
        'synthetic_atar_count' => 0,
        'gold_query_count' => 3,
        'failures' => [a_hash_including('source_id' => '600000009')],
      )
    end

    context 'when the set does not exist' do
      let(:make_request) { authenticated_get api_admin_search_evaluation_gold_query_set_path(0, format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'DELETE #destroy' do
    let(:make_request) { authenticated_delete api_admin_search_evaluation_gold_query_set_path(gold_query_set.id, format: :json) }
    let!(:gold_query_set) { create(:evaluation_gold_query_set) }

    before { create_gold_query_item(gold_query_set) }

    it { is_expected.to have_http_status :no_content }

    it 'deletes the set, its gold queries and their version history' do
      expect { api_response }
        .to change(EvaluationGoldQuerySet, :count).by(-1)
        .and change(EvaluationGoldQuery, :count).by(-3)
        .and change { Version.where(item_type: 'EvaluationGoldQuery').count }.by(-3)
    end

    context 'when an experiment uses the set' do
      before do
        create(:evaluation_experiment, name: 'baseline', gold_query_set_id: gold_query_set.id)
        create(:evaluation_experiment, name: 'with-rerank', gold_query_set_id: gold_query_set.id)
      end

      it { is_expected.to have_http_status :conflict }
      it { expect { api_response }.not_to change(EvaluationGoldQuerySet, :count) }
      it { expect { api_response }.not_to change(EvaluationGoldQuery, :count) }

      it 'names the experiments so the operator knows what to change' do
        expect(json_response['errors'].first).to include('status' => '409', 'title' => 'Gold query set is in use')
        expect(json_response['errors'].first['detail']).to include('baseline', 'with-rerank')
      end
    end

    context 'when the set does not exist' do
      let(:make_request) { authenticated_delete api_admin_search_evaluation_gold_query_set_path(0, format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST #create' do
    let(:make_request) { authenticated_post api_admin_search_evaluation_gold_query_sets_path(format: :json), params:, headers: }
    let(:headers) { { 'X-Whodunnit' => 'operator-1' } }
    let(:attributes) { { name: 'Set A', requested_size: 4, atar_percentage: 50 } }
    let(:params) { { data: { type: :gold_query_set, attributes: } } }

    before do
      allow(GenerateGoldQuerySetWorker).to receive(:perform_async)
      create_list(:tariff_knowledge_public_atar_ruling, 3)
      create_list(:tariff_knowledge_synthetic_atar, 3)
    end

    context 'with valid params' do
      it { is_expected.to have_http_status :accepted }
      it { expect { api_response }.to change(EvaluationGoldQuerySet, :count).by(1) }

      it 'returns the set, still generating, with its planned item count' do
        expect(json_response['data']['type']).to eq('gold_query_set')
        expect(json_response['data']['attributes']).to include(
          'name' => 'Set A', 'requested_size' => 4, 'atar_percentage' => 50,
          'planned_count' => 4, 'generated_count' => 0, 'failed_count' => 0,
          'status' => 'generating', 'failures' => []
        )
      end

      it 'queues the background job for the new set' do
        api_response

        expect(GenerateGoldQuerySetWorker).to have_received(:perform_async).with(json_response['data']['id'].to_i, an_instance_of(Array))
      end

      it 'takes created_by from the X-Whodunnit header' do
        expect(json_response['data']['attributes']['created_by']).to eq('operator-1')
      end
    end

    context 'when the body tries to set created_by or the counters directly' do
      let(:attributes) { { name: 'Set A', requested_size: 4, atar_percentage: 50, created_by: 'spoofed-user', status: 'ready', generated_count: 99 } }

      it 'ignores them' do
        expect(json_response['data']['attributes']).to include('created_by' => 'operator-1', 'status' => 'generating', 'generated_count' => 0)
      end
    end

    context 'with a missing name' do
      let(:attributes) { { requested_size: 4, atar_percentage: 50 } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect { api_response }.not_to change(EvaluationGoldQuerySet, :count) }
      it { expect(json_response['errors'].first['source']['pointer']).to eq('/data/attributes/name') }
    end

    context 'with a size above the limit' do
      let(:attributes) { { name: 'Set A', requested_size: 501, atar_percentage: 50 } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response['errors'].first['title']).to eq('must be between 1 and 500') }
    end

    context 'with a name that is already used' do
      before { create(:evaluation_gold_query_set, name: 'Set A') }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response['errors'].first['title']).to eq('is already taken') }

      it 'queues no job' do
        api_response

        expect(GenerateGoldQuerySetWorker).not_to have_received(:perform_async)
      end
    end

    context 'when there is nothing to generate from' do
      before do
        TariffKnowledge::PublicAtarRuling.dataset.delete
        TariffKnowledge::SyntheticAtar.dataset.delete
      end

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response['errors'].first['detail']).to include('no ATaR rulings or synthetic ATaRs') }
    end

    context 'without the data envelope' do
      let(:params) { { name: 'Set A' } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect { api_response }.not_to change(EvaluationGoldQuerySet, :count) }
    end
  end
end
