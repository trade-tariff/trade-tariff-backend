require 'stringio'

RSpec.describe 'Search failure logging' do
  after { TradeTariffRequest.reset }

  def capture_logs(&block)
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    subscribers = [Search::Logger, AiUsage::Logger].map do |klass|
      klass.new.tap { |subscriber| subscriber.define_singleton_method(:logger) { logger } }
    end
    callback = lambda do |event|
      subscriber = event.name.end_with?('.search') ? subscribers.first : subscribers.last
      subscriber.public_send(event.name.split('.').first, event)
    end
    ActiveSupport::Notifications.subscribed(callback, /\.(search|ai_usage)\z/, &block)
    output.string.lines.map { |line| JSON.parse(line) }
  end

  it 'retains the failure snapshot on each event while later failures accumulate' do
    events = []
    callback = ->(event) { events << event.payload }
    TradeTariffRequest.experiment = 'failure-cohort'
    ActiveSupport::Notifications.subscribed(callback, /\.search\z/) do
      Search::Instrumentation.search(request_id: 'journey', query: 'horse', search_type: 'evaluation') do
        Search::FailureCodes::ALL.each do |code|
          Search::Instrumentation.search_stage_failed(
            request_id: 'journey', search_type: 'interactive', failure_code: code,
            error_type: 'InvalidResponse', error_message: 'bad response'
          )
        end
        [[], { result_count: 0 }]
      end
    end

    expect(events.first).to include(Search::FailureCodes::ALL.index_with { false }.transform_keys(&:to_sym))
    expect(events.first).to include(search_degraded: false, experiment: 'failure-cohort', search_type: 'evaluation')
    expect(events[1]).to include(search_degraded: true, query_expansion_failed: true, embedding_generation_failed: false)
    expect(events.last).to include(Search::FailureCodes::ALL.index_with { true }.transform_keys(&:to_sym))
    expect(events.last).to include(search_type: 'evaluation', result_count: 0)
    expect(TradeTariffRequest.search_type).to be_nil
  end

  it 'logs embedding failure flags before the service rescue and retains provider cost' do
    error = VectorRetrievalService::EmbeddingGenerationError.new(
      'invalid embedding',
      ai_usage: AiUsage.metadata_for(model: EmbeddingService::MODEL, event_kind: 'vector_search_query_embedding', usage: { 'total_tokens' => 42 }),
    )
    TradeTariffRequest.set(request_id: 'journey', experiment: 'failure-cohort', request_source: 'frontend', client_id: 'evaluation') do
      TradeTariffRequest.record_search_failure(Search::FailureCodes::QUERY_EXPANSION_FAILED)
      logs = capture_logs do
        expect {
          AiUsage::Instrumentation.embedding_api_call(event_kind: 'vector_search_query_embedding', batch_size: 1, model: EmbeddingService::MODEL) { raise error }
        }.to raise_error(VectorRetrievalService::EmbeddingGenerationError)
      end
      expect(logs.last).to include(
        'event' => 'embedding_api_call_failed', 'request_id' => 'journey', 'experiment' => 'failure-cohort',
        'request_source' => 'frontend', 'client_id' => 'evaluation', 'total_tokens' => 42,
        'search_degraded' => true, 'embedding_generation_failed' => true, 'query_expansion_failed' => true,
        'vector_retrieval_failed' => false
      )
    end
  end

  {
    'search_query_expansion' => 'query_expansion_failed',
    'duplicate_question_validator' => 'duplicate_question_validation_failed',
    'interactive_search' => 'interactive_search_failed',
    'interactive_search_final_answer' => 'interactive_search_failed',
    'duplicate_question_retry' => 'interactive_search_failed',
  }.each do |operation, code|
    it "flags #{operation} before logging its failed API call" do
      logs = capture_logs do
        expect {
          Search::Instrumentation.api_call(request_id: 'journey', model: 'gpt-test', attempt_number: 1, operation:) { raise Faraday::TimeoutError }
        }.to raise_error(Faraday::TimeoutError)
      end
      expect(logs.last).to include('event' => 'api_call_completed', 'search_degraded' => true, code => true)
    end
  end

  it 'marks terminal failures without inventing a failed stage' do
    logs = capture_logs do
      expect {
        Search::Instrumentation.search(request_id: 'journey', query: 'horse', search_type: 'evaluation') { raise StandardError, 'unknown failure' }
      }.to raise_error(StandardError, 'unknown failure')
    end
    expect(logs.map { |entry| entry['event'] }).to eq(%w[search_started search_failed])
    expect(logs.last).to include('search_degraded' => true)
    expect(logs.last).to include(Search::FailureCodes::ALL.index_with { false })
  end

  it 'keeps healthy search usage and unrelated AI work distinguishable' do
    logs = capture_logs do
      AiUsage::Instrumentation.embedding_api_call(event_kind: 'vector_search_query_embedding', batch_size: 1, model: EmbeddingService::MODEL) { [] }
      AiUsage::Instrumentation.api_call(event_kind: 'atar_fact_extraction', model: 'gpt-test') { {} }
    end
    expect(logs.first).to include('search_degraded' => false, 'embedding_generation_failed' => false)
    expect(logs.last).not_to have_key('search_degraded')
  end
end
