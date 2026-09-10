RSpec.describe 'Queued internal searches', :internal do
  let(:path) { '/uk/internal/queued_searches' }
  let(:inputs) do
    {
      q: 'horse',
      as_of: '2025-01-02',
      request_id: 'search-journey',
      expanded_query: 'live horse',
      skip_question: false,
      answers: [{ question: 'Use?', answer: 'Racing', options: '["Racing","Breeding"]' }],
    }
  end

  around do |example|
    previous = ENV['QUEUED_SEARCH_ENABLED']
    ENV['QUEUED_SEARCH_ENABLED'] = 'true'
    example.run
  ensure
    ENV['QUEUED_SEARCH_ENABLED'] = previous
  end

  after do
    QueuedSearchWorker.jobs.each do |job|
      QueuedSearch.new(job['args'].first).delete
    end
  end

  describe 'POST /uk/internal/queued_searches' do
    context 'when submissions are not enabled' do
      [nil, 'false', 'invalid'].each do |value|
        it "rejects without storing or queueing when configured as #{value.inspect}" do
          ENV['QUEUED_SEARCH_ENABLED'] = value
          allow(QueuedSearch).to receive(:create).and_call_original

          post path, params: inputs, as: :json

          expect(response).to have_http_status(:service_unavailable)
          expect(response.parsed_body).not_to have_key('id')
          expect(QueuedSearch).not_to have_received(:create)
          expect(QueuedSearchWorker.jobs).to be_empty
        end
      end
    end

    it 'stores inputs and queues only the id' do
      post path, params: inputs.merge(configuration_overrides: { candidate_limit: 999 }), as: :json

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include('id' => be_present, 'status' => 'queued')
      id = response.parsed_body.fetch('id')
      expect(QueuedSearchWorker.jobs.last['args']).to eq([id])
      expect(QueuedSearch.new(id).payload.fetch('params')).to eq(inputs.deep_stringify_keys)
    end

    it 'does not execute search in the request' do
      allow(Api::Internal::SearchService).to receive(:new)

      post path, params: inputs, as: :json

      expect(Api::Internal::SearchService).not_to have_received(:new)
    end

    it 'preserves request context for the worker' do
      post path, params: inputs.merge(experiment: 'async-spike'),
                 headers: { 'X-Client-Id' => 'test-client', 'HTTP_X_ORIGINAL_USER_AGENT' => 'TradeTariffFrontend/test' }, as: :json

      payload = QueuedSearch.new(response.parsed_body.fetch('id')).payload
      expect(payload.fetch('context')).to include(
        'request_id' => 'search-journey', 'client_id' => 'test-client',
        'request_source' => 'frontend', 'experiment' => 'async-spike', 'as_of' => '2025-01-02'
      )
    end

    it 'does not accept a rejected enqueue' do
      id = SecureRandom.uuid
      allow(SecureRandom).to receive(:uuid).and_return(id)
      allow(QueuedSearchWorker).to receive(:perform_async).and_return(nil)

      post path, params: inputs, as: :json

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body).not_to have_key('id')
      expect(QueuedSearch.new(id).payload).to be_nil
    end

    it 'does not accept an enqueue connection failure' do
      id = SecureRandom.uuid
      allow(SecureRandom).to receive(:uuid).and_return(id)
      allow(QueuedSearchWorker).to receive(:perform_async).and_raise(RedisClient::ConnectionError, 'unavailable')

      post path, params: inputs, as: :json

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body).not_to have_key('id')
      expect(Sidekiq.redis { |redis| redis.ttl(QueuedSearch.new(id).key) }).to be_between(1, 3600)
    ensure
      QueuedSearch.new(id).delete
    end

    it 'does not accept a Redis outage' do
      allow(Sidekiq).to receive(:redis).and_raise(RedisClient::ConnectionError, 'unavailable')

      post path, params: inputs, as: :json

      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe 'GET /uk/internal/queued_searches/:id' do
    it 'allows work to finish after disabling submissions' do
      post path, params: { q: '' }, as: :json
      id = response.parsed_body.fetch('id')
      ENV['QUEUED_SEARCH_ENABLED'] = 'false'
      QueuedSearchWorker.new.perform(id)

      get "#{path}/#{id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('id' => id, 'status' => 'completed')
    end

    it 'reports pending without exposing inputs' do
      allow(Rails.configuration.action_controller).to receive(:perform_caching).and_return(true)
      post path, params: inputs, as: :json
      id = response.parsed_body.fetch('id')

      get "#{path}/#{id}", headers: { 'HTTP_USER_AGENT' => 'TradeTariffFrontend/test' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('id' => id, 'status' => 'queued')
      expect(response.parsed_body.keys).not_to include('params', 'context', 'result')
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'returns the original completed response' do
      # Empty queries exercise the real search service without external AI calls.
      post path, params: { q: '' }, as: :json
      id = response.parsed_body.fetch('id')
      QueuedSearchWorker.new.perform(id)

      get "#{path}/#{id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'status' => 'completed', 'response_status' => 200,
        'result' => { 'data' => [], 'meta' => { 'search_failures' => [] } }
      )
    end

    it 'serves terminal errors to the poller' do
      post path, params: inputs, as: :json
      id = response.parsed_body.fetch('id')
      search = QueuedSearch.new(id)
      search.claim
      search.finish(result: { errors: [{ title: 'Invalid query' }] }, response_status: 422)

      get "#{path}/#{id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'failed', 'response_status' => 422)
      expect(response.parsed_body.fetch('result')).to eq('errors' => [{ 'title' => 'Invalid query' }])
    end

    it 'reports a polling Redis outage' do
      allow(Sidekiq).to receive(:redis).and_raise(RedisClient::ConnectionError, 'unavailable')

      get "#{path}/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:service_unavailable)
    end

    it 'returns not found for unknown ids' do
      get "#{path}/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found after expiry' do
      post path, params: inputs, as: :json
      id = response.parsed_body.fetch('id')
      Sidekiq.redis { |redis| redis.expire(QueuedSearch.new(id).key, 0) }

      get "#{path}/#{id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
