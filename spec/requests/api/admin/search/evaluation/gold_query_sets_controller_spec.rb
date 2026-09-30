require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::GoldQuerySetsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }

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
