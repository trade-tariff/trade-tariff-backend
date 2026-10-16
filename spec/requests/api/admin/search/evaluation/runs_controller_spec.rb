require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::RunsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:experiment) { create(:evaluation_experiment, configuration_overrides: { 'simulator_model' => 'gpt-4o-mini' }) }

  describe 'POST #create' do
    let(:idempotency_key) { SecureRandom.uuid }
    let(:make_request) do
      authenticated_post api_admin_search_evaluation_runs_path(format: :json),
                         params: params, headers: { 'Idempotency-Key' => idempotency_key }
    end

    before { allow(EvalAppClient).to receive(:start_run!) }

    context 'without an Idempotency-Key header' do
      let(:params) { { data: { type: :run, attributes: { experiment_id: experiment.id, triggered_by: 'operator' } } } }
      let(:make_request) { authenticated_post api_admin_search_evaluation_runs_path(format: :json), params: params }

      it { is_expected.to have_http_status :bad_request }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }
    end

    context 'when retried with the same Idempotency-Key' do
      let(:params) { { data: { type: :run, attributes: { experiment_id: experiment.id, triggered_by: 'operator' } } } }

      it 'returns the original run instead of creating a second one' do
        api_response
        first_id = json_response['data']['id']

        authenticated_post api_admin_search_evaluation_runs_path(format: :json),
                           params: params, headers: { 'Idempotency-Key' => idempotency_key }
        second_id = JSON.parse(response.body)['data']['id']

        expect(response).to have_http_status(:created)
        expect(second_id).to eq(first_id)
        expect(EvaluationRun.count).to eq(1)
      end
    end

    context 'when sent twice with different Idempotency-Key values' do
      let(:params) { { data: { type: :run, attributes: { experiment_id: experiment.id, triggered_by: 'operator' } } } }

      it 'creates two separate runs' do
        api_response

        authenticated_post api_admin_search_evaluation_runs_path(format: :json),
                           params: params, headers: { 'Idempotency-Key' => SecureRandom.uuid }

        expect(EvaluationRun.count).to eq(2)
      end
    end

    context 'when the same Idempotency-Key is reused for a different experiment' do
      let(:params) { { data: { type: :run, attributes: { experiment_id: experiment.id, triggered_by: 'operator' } } } }

      it 'returns 409 instead of the first run, and does not create a second one' do
        api_response
        other_experiment = create(:evaluation_experiment)

        authenticated_post api_admin_search_evaluation_runs_path(format: :json),
                           params: { data: { type: :run, attributes: { experiment_id: other_experiment.id, triggered_by: 'operator' } } },
                           headers: { 'Idempotency-Key' => idempotency_key }

        expect(response).to have_http_status(:conflict)
        expect(EvaluationRun.count).to eq(1)
      end
    end

    context 'when the same Idempotency-Key is reused with different run-time overrides' do
      let(:params) { { data: { type: :run, attributes: { experiment_id: experiment.id, triggered_by: 'operator' } } } }

      it 'returns 409 instead of the first run, and does not create a second one' do
        api_response

        authenticated_post api_admin_search_evaluation_runs_path(format: :json),
                           params: {
                             data: {
                               type: :run,
                               attributes: {
                                 experiment_id: experiment.id,
                                 triggered_by: 'operator',
                                 configuration_overrides: { 'simulator_model' => 'gpt-4o' },
                               },
                             },
                           },
                           headers: { 'Idempotency-Key' => idempotency_key }

        expect(response).to have_http_status(:conflict)
        expect(EvaluationRun.count).to eq(1)
      end
    end

    context 'when retried with the same Idempotency-Key and the same run-time overrides, after an unrelated admin setting changed' do
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

      it 'still returns the original run — the retry is identical, only unrelated server state changed' do
        api_response
        first_id = json_response['data']['id']

        create(:admin_configuration, :integer, name: 'interactive_search_max_questions', value: 9)

        authenticated_post api_admin_search_evaluation_runs_path(format: :json),
                           params: params, headers: { 'Idempotency-Key' => idempotency_key }

        expect(response).to have_http_status(:created)
        expect(json_response['data']['id']).to eq(first_id)
        expect(EvaluationRun.count).to eq(1)
      end
    end

    context 'with an Idempotency-Key over 255 characters' do
      let(:params) { { data: { type: :run, attributes: { experiment_id: experiment.id, triggered_by: 'operator' } } } }
      let(:idempotency_key) { 'a' * 256 }

      it { is_expected.to have_http_status :bad_request }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }
    end

    context 'with an Idempotency-Key of exactly 255 characters' do
      let(:params) { { data: { type: :run, attributes: { experiment_id: experiment.id, triggered_by: 'operator' } } } }
      let(:idempotency_key) { 'a' * 255 }

      it { is_expected.to have_http_status :created }
    end

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
      it { expect(json_response.dig('errors', 0, 'detail')).to include('use_kg_context') }
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

    context 'when the runs\' experiments have gold query sets' do
      let(:gold_query_set) { create(:evaluation_gold_query_set) }
      let(:experiment) { create(:evaluation_experiment, gold_query_set_id: gold_query_set.id) }

      before { create(:evaluation_run, evaluation_experiment: experiment) }

      it 'includes the set of each run' do
        expect(json_response['data'].map { |run| run['attributes']['gold_query_set_id'] }).to eq([gold_query_set.id])
      end
    end

    context 'when a run has a stored intended_result_count' do
      before { create(:evaluation_run, evaluation_experiment: experiment, intended_result_count: 5) }

      it 'includes it as a plain stored value, not a fresh gold query set lookup' do
        expect(json_response['data'].map { |run| run['attributes']['intended_result_count'] }).to eq([5])
      end
    end

    context 'when a run has a generated label' do
      before { create(:evaluation_run, evaluation_experiment: experiment, label: 'vector based retrieval') }

      it 'includes it (AI-1437)' do
        expect(json_response['data'].map { |run| run['attributes']['label'] }).to eq(['vector based retrieval'])
      end
    end

    context "when a run's label hasn't been generated yet" do
      before { create(:evaluation_run, evaluation_experiment: experiment) }

      it 'includes it as nil, not an error or a missing key' do
        expect(json_response['data'].first['attributes']).to include('label' => nil)
      end
    end

    context 'when listing runs' do
      let(:experiment) { create(:evaluation_experiment, name: 'Baseline search') }

      before { create(:evaluation_run, evaluation_experiment: experiment) }

      it "includes each run's experiment name, so a run list doesn't have to look it up separately" do
        expect(json_response['data'].map { |run| run['attributes']['experiment_name'] }).to eq(['Baseline search'])
      end
    end

    context 'when filtering by status' do
      let(:filters) { { status: 'completed' } }

      before do
        create(:evaluation_run, evaluation_experiment: experiment, status: 'queued')
        create(:evaluation_run, evaluation_experiment: experiment, status: 'completed')
      end

      it { expect(json_response['data'].size).to eq(1) }
    end

    context 'when filtering by a from date' do
      let(:filters) { { from: 2.days.ago.to_date.iso8601 } }

      before do
        create(:evaluation_run, evaluation_experiment: experiment, created_at: 5.days.ago)
        create(:evaluation_run, evaluation_experiment: experiment, created_at: 1.day.ago)
      end

      it { is_expected.to have_http_status :success }

      it 'only returns runs created on or after that date, instead of raising' do
        expect(json_response['data'].size).to eq(1)
      end
    end

    context 'when filtering by a to date' do
      let(:filters) { { to: 2.days.ago.to_date.iso8601 } }

      before do
        create(:evaluation_run, evaluation_experiment: experiment, created_at: 5.days.ago)
        create(:evaluation_run, evaluation_experiment: experiment, created_at: 1.day.ago)
      end

      it { is_expected.to have_http_status :success }

      it 'only returns runs created on or before that date, instead of raising' do
        expect(json_response['data'].size).to eq(1)
      end
    end

    context 'when filtering by both a from and to date' do
      let(:filters) { { from: 4.days.ago.to_date.iso8601, to: 2.days.ago.to_date.iso8601 } }

      before do
        create(:evaluation_run, evaluation_experiment: experiment, created_at: 6.days.ago)
        create(:evaluation_run, evaluation_experiment: experiment, created_at: 3.days.ago)
        create(:evaluation_run, evaluation_experiment: experiment, created_at: 1.day.ago)
      end

      it { is_expected.to have_http_status :success }

      it 'only returns runs created within that range, instead of raising' do
        expect(json_response['data'].size).to eq(1)
      end
    end

    context 'when a run was created later the same day as the to date (AI-1436)' do
      let(:filters) { { to: Time.zone.today.iso8601 } }

      before { create(:evaluation_run, evaluation_experiment: experiment, created_at: Time.zone.now.end_of_day - 1.minute) }

      it { is_expected.to have_http_status :success }

      it 'includes the run created later that day, instead of excluding every run from the to date' do
        expect(json_response['data'].size).to eq(1)
      end
    end

    context 'when from and to are both set to today (AI-1436)' do
      let(:filters) { { from: Time.zone.today.iso8601, to: Time.zone.today.iso8601 } }

      before { create(:evaluation_run, evaluation_experiment: experiment, created_at: Time.zone.now) }

      it 'returns the run created today, instead of returning nothing' do
        expect(json_response['data'].size).to eq(1)
      end
    end

    context 'when the from date cannot be parsed (AI-1436)' do
      let(:filters) { { from: 'not-a-date' } }

      it { is_expected.to have_http_status :unprocessable_content }
    end

    context 'when the to date cannot be parsed (AI-1436)' do
      let(:filters) { { to: 'not-a-date' } }

      it { is_expected.to have_http_status :unprocessable_content }
    end

    context 'when the from date is a structured value rather than a string (AI-1436)' do
      let(:filters) { { from: %w[2026-10-13] } }

      it { is_expected.to have_http_status :unprocessable_content }
    end

    context 'when the to date is a structured value rather than a string (AI-1436)' do
      let(:filters) { { to: %w[2026-10-13] } }

      it { is_expected.to have_http_status :unprocessable_content }
    end
  end

  describe 'GET #show' do
    let(:run) { create(:evaluation_run, evaluation_experiment: experiment) }
    let(:make_request) { authenticated_get api_admin_search_evaluation_run_path(id, format: :json) }

    context 'with an existing run' do
      let(:id) { run.id }

      it { is_expected.to have_http_status :success }
      it { expect(json_response['data']['attributes']['gold_query_set_id']).to be_nil }
    end

    context 'when the run has run-time overrides' do
      let(:run) { create(:evaluation_run, evaluation_experiment: experiment, run_time_overrides: { 'max_rounds' => 3 }) }
      let(:id) { run.id }

      it 'includes the run-time overrides actually used, separate from the experiment default' do
        expect(json_response['data']['attributes']['run_time_overrides']).to eq({ 'max_rounds' => 3 })
      end
    end

    context 'when the run has accuracy counts and a costliest result' do
      let(:run) { create(:evaluation_run, evaluation_experiment: experiment, gold_in_top1_count: 3, gold_in_top5_count: 4) }
      let(:id) { run.id }

      before { run.update(max_cost_result_id: expensive_result.id) }

      # Memoised in a method, not a let, to stay within the memoized helper limit.
      def expensive_result
        @expensive_result ||= create(:evaluation_result, evaluation_run: run, source_id: 'A2', cost_usd: 0.05)
      end

      it 'includes the accuracy counts and a summary of the costliest and slowest results' do
        attributes = json_response['data']['attributes']

        expect(attributes).to include('gold_in_top1_count' => 3, 'gold_in_top5_count' => 4)
        expect(attributes['max_cost_result']).to include('id' => expensive_result.id.to_s, 'source_type' => 'atar', 'source_id' => 'A2', 'expected_code' => '8471300000', 'cost_usd' => '0.05')
      end
    end

    context 'when the run has no results yet' do
      let(:id) { run.id }

      it 'gives nil for an outlier summary' do
        expect(json_response['data']['attributes']['max_cost_result']).to be_nil
      end
    end

    context 'when the run\'s experiment has a gold query set' do
      let(:experiment) { create(:evaluation_experiment, gold_query_set_id: gold_query_set.id) }
      let(:id) { run.id }

      # Memoised in a method, not a let, to stay within the memoized helper limit.
      def gold_query_set
        @gold_query_set ||= create(:evaluation_gold_query_set)
      end

      it 'reports the set of the experiment' do
        expect(json_response['data']['attributes']['gold_query_set_id']).to eq(gold_query_set.id)
      end

      it 'cannot drift to a different set later, because the experiment source is locked once chosen (AI-1448)' do
        other_set = create(:evaluation_gold_query_set)

        expect { experiment.update(gold_query_set_id: other_set.id) }.to raise_error(Sequel::ValidationFailed)
        expect(json_response['data']['attributes']['gold_query_set_id']).to eq(gold_query_set.id)
      end
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

    context 'when the run was already cancelled' do
      let(:run) { create(:evaluation_run, evaluation_experiment: experiment, status: 'cancelled') }
      let(:params) { { data: { type: :run, attributes: { status: 'running' } } } }

      it { is_expected.to have_http_status :unprocessable_content }

      it 'leaves the run cancelled' do
        api_response
        expect(run.reload.status).to eq('cancelled')
      end
    end

    context 'when another request cancels the run after this one has loaded it' do
      let(:run) { create(:evaluation_run, evaluation_experiment: experiment, status: 'queued') }
      let(:params) { { data: { type: :run, attributes: { status: 'running' } } } }

      before do
        allow(EvaluationRun).to receive(:with_pk!).and_wrap_original do |original, id|
          loaded = original.call(id)
          allow(loaded).to receive(:lock!).and_wrap_original do |lock, *args|
            EvaluationRun.where(id: loaded.id).update(status: 'cancelled')
            lock.call(*args)
          end
          loaded
        end
      end

      it { is_expected.to have_http_status :unprocessable_content }

      it 'keeps the cancellation rather than overwriting it with running' do
        api_response
        expect(run.reload.status).to eq('cancelled')
      end
    end

    context 'with an unknown run' do
      let(:make_request) { authenticated_patch api_admin_search_evaluation_run_path(999_999, format: :json), params: { data: { type: :run, attributes: { status: 'completed' } } } }

      it { is_expected.to have_http_status :not_found }
    end
  end

  describe 'DELETE #bulk_destroy' do
    let(:make_request) { authenticated_delete bulk_destroy_api_admin_search_evaluation_runs_path(format: :json), params: { run_ids: run_ids } }
    let!(:run_a) { create(:evaluation_run, evaluation_experiment: experiment, status: 'completed') }
    let!(:run_b) { create(:evaluation_run, evaluation_experiment: experiment, status: 'failed') }

    # A plain method, not a `let`, to keep this describe block's memoized-helper count under
    # RuboCop's RSpec/MultipleMemoizedHelpers limit (it counts inherited `let`s too).
    def run_ids
      [run_a.id, run_b.id]
    end

    it { is_expected.to have_http_status :no_content }

    it 'deletes every selected run in one request' do
      expect { api_response }.to change(EvaluationRun, :count).by(-2)
    end

    it 'deletes a selected run\'s own results along with it' do
      result = create(:evaluation_result, evaluation_run: run_a)

      api_response

      expect(EvaluationResult.where(id: result.id)).to be_empty
    end

    it 'leaves runs outside the selection untouched' do
      untouched = create(:evaluation_run, evaluation_experiment: experiment, status: 'completed')

      api_response

      expect(EvaluationRun[untouched.id]).to be_present
    end

    context 'when the selection includes a queued run' do
      let!(:run_b) { create(:evaluation_run, evaluation_experiment: experiment, status: 'queued') }

      it { is_expected.to have_http_status :conflict }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }

      it 'says why and what to do next, and does not delete the other, eligible run either' do
        api_response

        expect(json_response.dig('errors', 0, 'detail')).to eq(
          'One or more selected runs are queued or running. Wait for them to finish, or cancel them, ' \
          'then try again.',
        )
        expect(EvaluationRun[run_a.id]).to be_present
      end
    end

    context 'when the selection includes a running run' do
      let!(:run_b) { create(:evaluation_run, evaluation_experiment: experiment, status: 'running') }

      it { is_expected.to have_http_status :conflict }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }
    end

    context 'when the selection includes an id that no longer exists' do
      def run_ids
        [run_a.id, 999_999]
      end

      it 'deletes the runs that do exist, rather than failing the whole request' do
        expect { api_response }.to change(EvaluationRun, :count).by(-1)
        expect(api_response).to have_http_status :no_content
      end
    end

    context 'when run_ids is missing from the request' do
      let(:make_request) { authenticated_delete bulk_destroy_api_admin_search_evaluation_runs_path(format: :json) }

      it { is_expected.to have_http_status :bad_request }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }
    end

    context 'when run_ids is an empty array' do
      def run_ids
        []
      end

      it { is_expected.to have_http_status :bad_request }
      it { expect { api_response }.not_to change(EvaluationRun, :count) }
    end

    context 'when run_ids contains something that is not an integer (AI-1441 review)' do
      def run_ids
        [run_a.id, 'not-an-id']
      end

      it 'rejects the request with 400, rather than letting a malformed id reach Postgres as a 500' do
        expect(api_response).to have_http_status :bad_request
      end

      it 'does not delete anything from the valid part of the selection either' do
        expect { api_response }.not_to change(EvaluationRun, :count)
      end
    end

    # A single-process spec can mutate a row before a query runs, but it cannot make a second,
    # genuinely concurrent transaction race this one on the same connection -- FOR UPDATE's
    # whole purpose is to block a *different* transaction, which a single-threaded stub can't
    # exercise. What a spec here can honestly prove is that the mechanism is actually wired up:
    # that the SELECT this action runs is a locking one, not a plain read (AI-1441 review --
    # Copilot correctly flagged an earlier version of this spec that stubbed the mutation before
    # the very first read in *either* the old or new implementation, so it passed against both
    # and proved nothing about the fix specifically).
    context 'with the row-locking mechanism' do
      def run_ids
        [run_a.id, run_b.id]
      end

      it 'selects the rows with FOR UPDATE, so a concurrent PATCH on one of them has to wait for this transaction to finish' do
        # Sequel datasets are frozen, so stubbing a method on one directly (e.g. via
        # allow(dataset).to receive(:for_update)) silently never fires. Reading the real SQL
        # Sequel sends to Postgres, through its own query logger, sidesteps that entirely.
        log = StringIO.new
        EvaluationRun.db.loggers << Logger.new(log)

        begin
          api_response
        ensure
          EvaluationRun.db.loggers.pop
        end

        expect(log.string).to match(/FOR UPDATE/i)
      end
    end

    context 'when run_ids is not an array at all' do
      let(:make_request) { authenticated_delete bulk_destroy_api_admin_search_evaluation_runs_path(format: :json), params: { run_ids: run_a.id } }

      it 'rejects it rather than silently treating the single value as a one-id selection' do
        expect(api_response).to have_http_status :bad_request
      end

      it 'does not delete the run that the bare id happened to name' do
        expect { api_response }.not_to change(EvaluationRun, :count)
      end
    end

    context 'when run_ids contains a float (AI-1441 review)' do
      let(:make_request) { authenticated_delete bulk_destroy_api_admin_search_evaluation_runs_path(format: :json), params: { run_ids: [run_a.id, 1.9] } }

      it 'rejects it, rather than truncating 1.9 into a real id via Integer() coercion' do
        expect(api_response).to have_http_status :bad_request
      end

      it 'does not delete anything from the valid part of the selection either' do
        expect { api_response }.not_to change(EvaluationRun, :count)
      end
    end

    context "when run_ids contains an id too large for Postgres's integer column (AI-1441 review)" do
      let(:make_request) { authenticated_delete bulk_destroy_api_admin_search_evaluation_runs_path(format: :json), params: { run_ids: [run_a.id, 2_147_483_648] } }

      it 'rejects it with 400 because it cannot be a valid run id' do
        expect(api_response).to have_http_status :bad_request
      end
    end
  end
end
