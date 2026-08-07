require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::ResultsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:experiment) { create(:evaluation_experiment) }
  let(:run) { create(:evaluation_run, evaluation_experiment: experiment) }

  describe 'POST #create' do
    let(:make_request) { authenticated_post api_admin_search_evaluation_results_path(format: :json), params: { data: items } }

    context 'with every item valid' do
      let(:items) do
        [
          { run_id: run.id, source_type: 'atar', source_id: 'A1', persona: 'original', expected_code: '8471300000', final_code: '8471300000' },
          { run_id: run.id, source_type: 'atar', source_id: 'A2', persona: 'original', expected_code: '8471300000', final_code: '8471300000' },
        ]
      end

      it { is_expected.to have_http_status :ok }
      it { expect { api_response }.to change(EvaluationResult, :count).by(2) }

      it 'returns one serialized result per item, in order' do
        api_response
        expect(json_response['data'].map { |item| item['attributes']['source_id'] }).to eq(%w[A1 A2])
      end
    end

    context 'with a mix of valid and invalid items' do
      let(:items) do
        [
          { run_id: run.id, source_type: 'atar', source_id: 'A1', persona: 'original', expected_code: '8471300000' },
          { run_id: 999_999, source_type: 'atar', source_id: 'A2', persona: 'original', expected_code: '8471300000' },
        ]
      end

      it { is_expected.to have_http_status :multi_status }
      it { expect { api_response }.to change(EvaluationResult, :count).by(1) }

      it 'ingests the valid item and reports an error for the invalid one, at its original index' do
        api_response
        expect(json_response['data'][0]).to include('id')
        expect(json_response['data'][1]).to include('error', 'index' => 1)
      end
    end

    context 'with every item invalid' do
      let(:items) { [{ run_id: 999_999, source_type: 'atar', source_id: 'A1', persona: 'original', expected_code: '8471300000' }] }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect { api_response }.not_to change(EvaluationResult, :count) }
    end

    context 'when retried with the same source_id/persona under the same run' do
      let(:item) { { run_id: run.id, source_type: 'atar', source_id: 'A1', persona: 'original', expected_code: '8471300000', final_code: 'first' } }

      before { authenticated_post api_admin_search_evaluation_results_path(format: :json), params: { data: [item] } }

      it 'overwrites rather than duplicates' do
        expect {
          authenticated_post api_admin_search_evaluation_results_path(format: :json), params: { data: [item.merge(final_code: 'second')] }
        }.not_to change(EvaluationResult, :count)
      end

      it 'reflects the latest attributes' do
        authenticated_post api_admin_search_evaluation_results_path(format: :json), params: { data: [item.merge(final_code: 'second')] }
        result = EvaluationResult.first(run_id: run.id, source_id: 'A1', persona: 'original')
        expect(result.final_code).to eq('second')
      end
    end
  end

  describe 'GET #index' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_results_path(format: :json), params: { run_id: run.id } }

    before do
      create(:evaluation_result, evaluation_run: run)
      create(:evaluation_result, evaluation_run: create(:evaluation_run, evaluation_experiment: experiment))
    end

    it { is_expected.to have_http_status :success }
    it { expect(json_response['data'].size).to eq(1) }
  end

  describe 'GET #show' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_result_path(id, format: :json) }

    context 'with an existing result' do
      let(:id) { create(:evaluation_result, evaluation_run: run).id }

      it { is_expected.to have_http_status :success }
    end

    context 'with an unknown result' do
      let(:id) { 999_999 }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
