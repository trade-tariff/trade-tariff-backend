require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::ExperimentsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }

  describe 'GET #index' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_experiments_path(format: :json) }

    context 'with existing experiments' do
      before { create_list(:evaluation_experiment, 2) }

      it { is_expected.to have_http_status :success }
      it { expect(json_response['data'].size).to eq(2) }
    end

    context 'with no experiments' do
      it { is_expected.to have_http_status :success }
      it { expect(json_response['data']).to eq([]) }
    end
  end

  describe 'GET #show' do
    let(:experiment) { create(:evaluation_experiment) }
    let(:make_request) { authenticated_get api_admin_search_evaluation_experiment_path(id, format: :json) }

    context 'with an existing experiment' do
      let(:id) { experiment.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response['data']['attributes']['name']).to eq(experiment.name) }
    end

    context 'with an unknown experiment' do
      let(:id) { 999_999 }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'POST #create' do
    let(:make_request) { authenticated_post api_admin_search_evaluation_experiments_path(format: :json), params: params }

    context 'with valid params' do
      let(:params) do
        {
          data: {
            type: :experiment,
            attributes: {
              name: 'baseline-gpt4o',
              description: 'baseline run',
              configuration_overrides: { 'simulator_model' => 'gpt-4o-mini' },
            },
          },
        }
      end

      it { is_expected.to have_http_status :created }
      it { expect { api_response }.to change(EvaluationExperiment, :count).by(1) }
      it { expect(json_response['data']['attributes']['name']).to eq('baseline-gpt4o') }

      it 'persists the configuration_overrides hash' do
        api_response
        expect(json_response['data']['attributes']['configuration_overrides']).to eq('simulator_model' => 'gpt-4o-mini')
      end
    end

    context 'with a missing name' do
      let(:params) { { data: { type: :experiment, attributes: { description: 'no name' } } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response).to include('errors') }
      it { expect { api_response }.not_to change(EvaluationExperiment, :count) }
    end

    context 'with a duplicate name' do
      let!(:existing) { create(:evaluation_experiment) }
      let(:params) { { data: { type: :experiment, attributes: { name: existing.name } } } }

      it { is_expected.to have_http_status :unprocessable_content }
    end
  end

  describe 'PATCH #update' do
    let(:experiment) { create(:evaluation_experiment, enabled: true) }
    let(:make_request) { authenticated_patch api_admin_search_evaluation_experiment_path(id, format: :json), params: params }

    context 'when toggling enabled off' do
      let(:id) { experiment.id }
      let(:params) { { data: { type: :experiment, attributes: { enabled: false } } } }

      it { is_expected.to have_http_status :success }
      it { expect { api_response }.to change { experiment.reload.enabled }.from(true).to(false) }
    end

    context 'with an unknown experiment' do
      let(:id) { 999_999 }
      let(:params) { { data: { type: :experiment, attributes: { enabled: false } } } }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
