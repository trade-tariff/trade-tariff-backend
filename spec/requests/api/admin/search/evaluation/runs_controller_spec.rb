require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::RunsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:experiment) { create(:evaluation_experiment, configuration_overrides: { 'simulator_model' => 'gpt-4o-mini' }) }

  describe 'POST #create' do
    let(:make_request) { authenticated_post api_admin_search_evaluation_runs_path(format: :json), params: params }

    context 'with a valid experiment and no run-time overrides' do
      let(:params) do
        { data: { type: :run, attributes: { experiment_id: experiment.id, triggered_by: 'operator' } } }
      end

      it { is_expected.to have_http_status :created }
      it { expect { api_response }.to change(EvaluationRun, :count).by(1) }

      it 'resolves the effective_configuration from the experiment overrides' do
        api_response
        expect(json_response['data']['attributes']['effective_configuration']['simulator_model']).to eq('gpt-4o-mini')
      end

      it 'starts in queued status' do
        api_response
        expect(json_response['data']['attributes']['status']).to eq('queued')
      end
    end

    context 'with run-time overrides layered on top of the experiment overrides' do
      let(:params) do
        {
          data: {
            type: :run,
            attributes: {
              experiment_id: experiment.id,
              triggered_by: 'operator',
              configuration_overrides: { 'simulator_model' => 'gpt-4o' },
            },
          },
        }
      end

      it 'applies the run-time override' do
        api_response
        expect(json_response['data']['attributes']['effective_configuration']['simulator_model']).to eq('gpt-4o')
      end
    end

    context 'with a nonexistent experiment_id' do
      let(:params) { { data: { type: :run, attributes: { experiment_id: 999_999, triggered_by: 'operator' } } } }

      it { is_expected.to have_http_status :not_found }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }
    end

    context 'with a disallowed run-time override' do
      let(:params) do
        {
          data: {
            type: :run,
            attributes: {
              experiment_id: experiment.id,
              triggered_by: 'operator',
              configuration_overrides: { 'use_kg_context' => true },
            },
          },
        }
      end

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response['error']).to include('use_kg_context') }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }
    end
  end

  describe 'GET #index' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_runs_path(format: :json), params: filters }
    let(:filters) { {} }

    context 'when filtering by experiment_id' do
      let(:other_experiment) { create(:evaluation_experiment) }
      let(:filters) { { experiment_id: experiment.id } }

      before do
        create(:evaluation_run, evaluation_experiment: experiment)
        create(:evaluation_run, evaluation_experiment: other_experiment)
      end

      it { is_expected.to have_http_status :success }
      it { expect(json_response['data'].size).to eq(1) }
    end

    context 'when filtering by status' do
      let(:filters) { { status: 'completed' } }

      before do
        create(:evaluation_run, evaluation_experiment: experiment, status: 'queued')
        create(:evaluation_run, evaluation_experiment: experiment, status: 'completed')
      end

      it { expect(json_response['data'].size).to eq(1) }
    end
  end

  describe 'GET #show' do
    let(:run) { create(:evaluation_run, evaluation_experiment: experiment) }
    let(:make_request) { authenticated_get api_admin_search_evaluation_run_path(id, format: :json) }

    context 'with an existing run' do
      let(:id) { run.id }

      it { is_expected.to have_http_status :success }
    end

    context 'with an unknown run' do
      let(:id) { 999_999 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'PATCH #update' do
    let(:run) { create(:evaluation_run, evaluation_experiment: experiment, status: 'running') }
    let(:make_request) { authenticated_patch api_admin_search_evaluation_run_path(run.id, format: :json), params: params }

    context 'when moving into a terminal status' do
      let(:params) { { data: { type: :run, attributes: { status: 'completed' } } } }

      before { create(:evaluation_result, evaluation_run: run) }

      it { is_expected.to have_http_status :success }

      it 'reconciles aggregates from the run results' do
        api_response
        expect(run.reload.result_count).to eq(1)
      end
    end

    context 'when moving from queued to running' do
      let(:run) { create(:evaluation_run, evaluation_experiment: experiment, status: 'queued') }
      let(:params) { { data: { type: :run, attributes: { status: 'running' } } } }

      before { create(:evaluation_result, evaluation_run: run) }

      it 'does not reconcile aggregates' do
        api_response
        expect(run.reload.result_count).to eq(0)
      end
    end

    context 'with an invalid status' do
      let(:params) { { data: { type: :run, attributes: { status: 'bogus' } } } }

      it { is_expected.to have_http_status :unprocessable_content }
    end

    context 'with an unknown run' do
      let(:make_request) { authenticated_patch api_admin_search_evaluation_run_path(999_999, format: :json), params: { data: { type: :run, attributes: { status: 'completed' } } } }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
