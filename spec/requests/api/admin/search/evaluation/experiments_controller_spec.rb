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
    let(:make_request) { authenticated_post api_admin_search_evaluation_experiments_path(format: :json), params:, headers: }
    let(:headers) { {} }

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

    context 'when the request carries an X-Whodunnit header' do
      let(:headers) { { 'X-Whodunnit' => 'operator-1' } }
      let(:params) { { data: { type: :experiment, attributes: { name: 'baseline-gpt4o' } } } }

      it 'sets created_by from the header rather than the request body' do
        api_response
        expect(json_response['data']['attributes']['created_by']).to eq('operator-1')
      end
    end

    context 'when the request body attempts to set created_by directly' do
      let(:params) { { data: { type: :experiment, attributes: { name: 'baseline-gpt4o', created_by: 'spoofed-user' } } } }

      it 'ignores the client-supplied value' do
        api_response
        expect(json_response['data']['attributes']['created_by']).to be_nil
      end
    end

    context 'with a gold query set' do
      let(:gold_query_set) { create(:evaluation_gold_query_set) }
      let(:params) { { data: { type: :experiment, attributes: { name: 'with-set', gold_query_set_id: gold_query_set.id } } } }

      it { is_expected.to have_http_status :created }
      it { expect(json_response['data']['attributes']['gold_query_set_id']).to eq(gold_query_set.id) }
    end

    context 'without a gold query set' do
      let(:params) { { data: { type: :experiment, attributes: { name: 'no-set' } } } }

      it { expect(json_response['data']['attributes']['gold_query_set_id']).to be_nil }
    end

    context 'with a gold query set that does not exist' do
      let(:params) { { data: { type: :experiment, attributes: { name: 'bad-set', gold_query_set_id: 999_999 } } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect { api_response }.not_to change(EvaluationExperiment, :count) }
      it { expect(json_response['errors'].first['source']['pointer']).to eq('/data/attributes/gold_query_set_id') }
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

    context 'when choosing a gold query set' do
      let(:id) { experiment.id }
      let(:params) { { data: { type: :experiment, attributes: { gold_query_set_id: gold_query_set.id } } } }

      # Memoised in a method, not a let, to stay within the memoized helper limit.
      def gold_query_set
        @gold_query_set ||= create(:evaluation_gold_query_set)
      end

      it { is_expected.to have_http_status :success }
      it { expect { api_response }.to change { experiment.reload.gold_query_set_id }.from(nil).to(gold_query_set.id) }
    end

    context 'when choosing a gold query set that does not exist' do
      let(:id) { experiment.id }
      let(:params) { { data: { type: :experiment, attributes: { gold_query_set_id: 999_999 } } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect { api_response }.not_to(change { experiment.reload.gold_query_set_id }) }
    end

    context 'when trying to clear an already-chosen gold query set' do
      let(:id) { experiment.id }
      let(:experiment) { create(:evaluation_experiment, gold_query_set_id: create(:evaluation_gold_query_set).id) }
      let(:params) { { data: { type: :experiment, attributes: { gold_query_set_id: nil } } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect { api_response }.not_to(change { experiment.reload.gold_query_set_id }) }
    end

    context 'when choosing a synthetic input set' do
      let(:id) { experiment.id }
      let(:params) { { data: { type: :experiment, attributes: { synthetic_input_set_id: synthetic_input_set.id } } } }

      def synthetic_input_set
        @synthetic_input_set ||= create(:evaluation_synthetic_input_set)
      end

      it { is_expected.to have_http_status :success }
      it { expect { api_response }.to change { experiment.reload.synthetic_input_set_id }.from(nil).to(synthetic_input_set.id) }
    end

    context 'when trying to change an already-chosen synthetic input set' do
      let(:id) { experiment.id }
      let(:experiment) { create(:evaluation_experiment, synthetic_input_set_id: create(:evaluation_synthetic_input_set).id) }
      let(:params) { { data: { type: :experiment, attributes: { synthetic_input_set_id: create(:evaluation_synthetic_input_set).id } } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect { api_response }.not_to(change { experiment.reload.synthetic_input_set_id }) }
    end

    context 'when another request chooses a different source after this one has loaded the experiment' do
      let(:id) { experiment.id }
      let(:params) { { data: { type: :experiment, attributes: { gold_query_set_id: gold_query_set.id } } } }

      def gold_query_set
        @gold_query_set ||= create(:evaluation_gold_query_set)
      end

      def other_set
        @other_set ||= create(:evaluation_synthetic_input_set)
      end

      before do
        allow(EvaluationExperiment).to receive(:with_pk!).and_wrap_original do |original, id|
          loaded = original.call(id)
          allow(loaded).to receive(:lock!).and_wrap_original do |lock, *args|
            EvaluationExperiment.where(id: loaded.id).update(synthetic_input_set_id: other_set.id)
            lock.call(*args)
          end
          loaded
        end
      end

      it { is_expected.to have_http_status :unprocessable_content }

      it "keeps the other request's choice rather than overwriting it" do
        api_response

        expect(experiment.reload.synthetic_input_set_id).to eq(other_set.id)
        expect(experiment.reload.gold_query_set_id).to be_nil
      end
    end

    context 'with an unknown experiment' do
      let(:id) { 999_999 }
      let(:params) { { data: { type: :experiment, attributes: { enabled: false } } } }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'DELETE #destroy' do
    let(:make_request) { authenticated_delete api_admin_search_evaluation_experiment_path(experiment.id, format: :json) }
    let!(:experiment) { create(:evaluation_experiment) }

    it { is_expected.to have_http_status :no_content }
    it { expect { api_response }.to change(EvaluationExperiment, :count).by(-1) }

    context 'when its runs have all finished' do
      before do
        create(:evaluation_run, evaluation_experiment: experiment, status: 'completed')
        create(:evaluation_run, evaluation_experiment: experiment, status: 'cancelled')
      end

      it { is_expected.to have_http_status :no_content }

      it 'deletes the experiment and its finished runs' do
        expect { api_response }
          .to change(EvaluationExperiment, :count).by(-1)
          .and change(EvaluationRun, :count).by(-2)
      end
    end

    context 'when one of its runs is queued' do
      before { create(:evaluation_run, evaluation_experiment: experiment, status: 'queued') }

      it { is_expected.to have_http_status :conflict }
      it { expect { api_response }.not_to change(EvaluationExperiment, :count) }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }

      it 'says why and what to do next' do
        expect(json_response.dig('errors', 0, 'detail')).to eq(
          'This experiment cannot be deleted while one of its runs is queued or running. ' \
          'Wait for the run to finish, or cancel it, then try again.',
        )
      end
    end

    context 'when one of its runs is running' do
      before { create(:evaluation_run, evaluation_experiment: experiment, status: 'running') }

      it { is_expected.to have_http_status :conflict }
      it { expect { api_response }.not_to change(EvaluationExperiment, :count) }
    end

    context 'when the experiment does not exist' do
      let(:make_request) { authenticated_delete api_admin_search_evaluation_experiment_path(0, format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'the set an experiment is scored against' do
    let(:gold_query_set) { create(:evaluation_gold_query_set, name: 'Baseline GQS') }
    let(:synthetic_input_set) { create(:evaluation_synthetic_input_set, name: 'Baseline SIS') }

    def attributes_of(name)
      json_response['data'].find { |row| row['attributes']['name'] == name }['attributes']
    end

    describe 'GET #index' do
      let(:make_request) { authenticated_get api_admin_search_evaluation_experiments_path(format: :json) }

      before do
        create(:evaluation_experiment, name: 'on-gold', gold_query_set_id: gold_query_set.id)
        create(:evaluation_experiment, name: 'on-synthetic', synthetic_input_set_id: synthetic_input_set.id)
        create(:evaluation_experiment, name: 'on-nothing')
      end

      it 'names the set of an experiment that uses a gold query set' do
        expect(attributes_of('on-gold')).to include('source_type' => 'gold_query_set', 'source_name' => 'Baseline GQS')
      end

      it 'names the set of an experiment that uses a synthetic input set' do
        expect(attributes_of('on-synthetic')).to include('source_type' => 'synthetic_input_set', 'source_name' => 'Baseline SIS')
      end

      it 'has no source for an experiment that has not chosen a set yet' do
        expect(attributes_of('on-nothing')).to include('source_type' => nil, 'source_name' => nil)
      end

      it 'looks the sets up once for the whole page, not once per experiment' do
        create_list(:evaluation_experiment, 4) { |experiment, index| experiment.update(gold_query_set_id: create(:evaluation_gold_query_set, name: "GQS #{index}").id) }
        log = StringIO.new
        EvaluationExperiment.db.loggers << Logger.new(log)

        begin
          api_response
        ensure
          EvaluationExperiment.db.loggers.pop
        end

        expect(log.string.scan(/FROM "uk"."evaluation_gold_query_sets"/).size).to eq(1)
        expect(log.string.scan(/FROM "uk"."evaluation_synthetic_input_sets"/).size).to eq(1)
      end
    end

    describe 'GET #show' do
      let(:experiment) { create(:evaluation_experiment, gold_query_set_id: gold_query_set.id) }
      let(:make_request) { authenticated_get api_admin_search_evaluation_experiment_path(experiment.id, format: :json) }

      it 'names the set' do
        expect(json_response['data']['attributes']).to include('source_type' => 'gold_query_set', 'source_name' => 'Baseline GQS')
      end
    end
  end
end
