require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::SearchesController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:make_request) { authenticated_post api_admin_search_evaluation_searches_path(format: :json), params: params, as: :json }

  before do
    # Force the opensearch-only retrieval path, with query expansion off, so a real search in
    # these specs doesn't make a live OpenAI/embeddings call and fail under WebMock (mirrors
    # the worker spec and the old synchronous controller spec).
    allow(AdminConfiguration).to receive(:option_value).and_call_original
    allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('opensearch')
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(false)
    allow(ExpandSearchQueryService).to receive(:call).and_wrap_original do |_method, query|
      ExpandSearchQueryService::Result.new(expanded_query: query, reason: nil)
    end
  end

  after do
    EvaluationQueuedSearchWorker.jobs.each do |job|
      QueuedSearch.new(job['args'].first).delete
    end
  end

  describe 'POST #create' do
    context 'with a disallowed configuration_overrides key' do
      let(:params) { { q: 'horses', configuration_overrides: { 'use_kg_context' => true } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response).to include('errors') }

      it 'does not queue a search' do
        api_response
        expect(EvaluationQueuedSearchWorker.jobs).to be_empty
      end
    end

    context 'with an allowed key but an invalid value' do
      let(:params) { { q: 'horses', configuration_overrides: { 'rrf_k' => 'abc' } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response).to include('errors') }
    end

    context 'with a valid query' do
      let(:params) { { q: 'horses', configuration_overrides: { 'candidate_limit' => 5 } } }

      it { is_expected.to have_http_status :accepted }
      it { expect(json_response).to include('id' => be_present, 'status' => 'queued') }

      it 'queues the search on the dedicated evaluation queue, not :default' do
        api_response
        expect(EvaluationQueuedSearchWorker.jobs.last['queue']).to eq('evaluation')
      end

      it 'stores configuration_overrides and the evaluation search_type on the queued search' do
        api_response
        id = json_response.fetch('id')
        expect(QueuedSearch.new(id).payload.fetch('params')).to include(
          'configuration_overrides' => { 'candidate_limit' => 5 }, 'search_type' => 'evaluation',
        )
      end

      it 'does not execute the search in the request' do
        allow(Api::Internal::SearchService).to receive(:new)

        api_response

        expect(Api::Internal::SearchService).not_to have_received(:new)
      end

      it 'stores the request context for the worker' do
        api_response
        id = json_response.fetch('id')
        expect(QueuedSearch.new(id).payload.fetch('context')).to include('request_id', 'as_of')
      end
    end

    context 'without any configuration_overrides' do
      let(:params) { { q: 'horses' } }

      it 'stores an empty configuration_overrides' do
        api_response
        id = json_response.fetch('id')
        expect(QueuedSearch.new(id).payload.dig('params', 'configuration_overrides')).to eq({})
      end
    end

    context 'when the enqueue is rejected' do
      let(:params) { { q: 'horses' } }

      it 'does not accept a rejected enqueue' do
        id = SecureRandom.uuid
        allow(SecureRandom).to receive(:uuid).and_return(id)
        allow(EvaluationQueuedSearchWorker).to receive(:perform_async).and_return(nil)

        api_response

        expect(response).to have_http_status(:service_unavailable)
        expect(json_response).not_to have_key('id')
        expect(QueuedSearch.new(id).payload).to be_nil
      end

      it 'does not accept an enqueue connection failure' do
        id = SecureRandom.uuid
        allow(SecureRandom).to receive(:uuid).and_return(id)
        allow(EvaluationQueuedSearchWorker).to receive(:perform_async).and_raise(RedisClient::ConnectionError, 'unavailable')

        api_response

        expect(response).to have_http_status(:service_unavailable)
        expect(json_response).not_to have_key('id')
      ensure
        QueuedSearch.new(id).delete
      end

      it 'does not accept a Redis outage' do
        allow(Sidekiq).to receive(:redis).and_raise(RedisClient::ConnectionError, 'unavailable')

        api_response

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

  describe 'GET #show' do
    let(:params) { { q: 'horses' } }

    it 'reports queued without exposing inputs' do
      api_response
      id = json_response.fetch('id')

      get api_admin_search_evaluation_search_path(id, format: :json)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('id' => id, 'status' => 'queued')
      expect(JSON.parse(response.body).keys).not_to include('params', 'context')
    end

    it 'returns the completed search once the worker has run' do
      api_response
      id = json_response.fetch('id')
      EvaluationQueuedSearchWorker.new.perform(id)

      get api_admin_search_evaluation_search_path(id, format: :json)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('status' => 'completed', 'response_status' => 200)
    end

    it 'serves terminal errors to the poller' do
      api_response
      id = json_response.fetch('id')
      search = QueuedSearch.new(id)
      search.claim
      search.finish(result: { errors: [{ title: 'Invalid query' }] }, response_status: 422)

      get api_admin_search_evaluation_search_path(id, format: :json)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('status' => 'failed', 'response_status' => 422)
      expect(JSON.parse(response.body).fetch('result')).to eq('errors' => [{ 'title' => 'Invalid query' }])
    end

    it 'reports a polling Redis outage' do
      allow(Sidekiq).to receive(:redis).and_raise(RedisClient::ConnectionError, 'unavailable')

      get api_admin_search_evaluation_search_path(SecureRandom.uuid, format: :json)

      expect(response).to have_http_status(:service_unavailable)
    end

    it 'returns not found for unknown ids' do
      get api_admin_search_evaluation_search_path(SecureRandom.uuid, format: :json)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found after expiry' do
      api_response
      id = json_response.fetch('id')
      Sidekiq.redis { |redis| redis.expire(QueuedSearch.new(id).key, 0) }

      get api_admin_search_evaluation_search_path(id, format: :json)

      expect(response).to have_http_status(:not_found)
    end
  end
end
