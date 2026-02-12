require 'stringio'

RSpec.describe Search::Logger do
  let(:log_output) { StringIO.new }
  let(:test_logger) { ActiveSupport::Logger.new(log_output) }
  let(:logger_instance) do
    logger = test_logger
    described_class.new.tap do |l|
      l.define_singleton_method(:logger) { logger }
    end
  end

  def build_event(name, payload)
    ActiveSupport::Notifications::Event.new(
      "#{name}.search",
      Time.current,
      Time.current,
      SecureRandom.hex(10),
      payload,
    )
  end

  def parsed_log_output
    log_output.rewind
    lines = log_output.read.strip.split("\n")
    JSON.parse(lines.last)
  end

  shared_examples 'a search log entry' do |method_name, event_name, payload|
    it 'includes service and timestamp' do
      logger_instance.public_send(method_name, build_event(event_name, payload))
      json = parsed_log_output
      expect(json['service']).to eq('search')
      expect(json['timestamp']).to be_present
    end
  end

  describe '#search_started' do
    let(:payload) { { request_id: 'req-1', query: 'horses', search_type: 'interactive' } }

    it_behaves_like 'a search log entry', :search_started, 'search_started',
                    { request_id: 'req-1', query: 'horses', search_type: 'interactive' }

    it 'logs correct fields' do
      logger_instance.search_started(build_event('search_started', payload))
      json = parsed_log_output
      expect(json['event']).to eq('search_started')
      expect(json['request_id']).to eq('req-1')
      expect(json['query']).to eq('horses')
      expect(json['search_type']).to eq('interactive')
    end
  end

  describe '#query_expanded' do
    let(:payload) do
      { request_id: 'req-1',
        original_query: 'horses',
        expanded_query: 'equine animals',
        reason: 'colloquial',
        duration_ms: 150.5 }
    end

    it_behaves_like 'a search log entry', :query_expanded, 'query_expanded',
                    { request_id: 'req-1',
                      original_query: 'horses',
                      expanded_query: 'equine animals',
                      reason: 'colloquial',
                      duration_ms: 150.5 }

    it 'logs correct fields' do
      logger_instance.query_expanded(build_event('query_expanded', payload))
      json = parsed_log_output
      expect(json['event']).to eq('query_expanded')
      expect(json['original_query']).to eq('horses')
      expect(json['expanded_query']).to eq('equine animals')
      expect(json['duration_ms']).to eq(150.5)
    end
  end

  describe '#api_call_completed' do
    let(:payload) do
      { request_id: 'req-1', model: 'gpt-4', duration_ms: 2500.0, response_type: 'answers', attempt_number: 1 }
    end

    it_behaves_like 'a search log entry', :api_call_completed, 'api_call_completed',
                    { request_id: 'req-1',
                      model: 'gpt-4',
                      duration_ms: 2500.0,
                      response_type: 'answers',
                      attempt_number: 1 }

    it 'logs correct fields' do
      logger_instance.api_call_completed(build_event('api_call_completed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('api_call_completed')
      expect(json['model']).to eq('gpt-4')
      expect(json['duration_ms']).to eq(2500.0)
      expect(json['response_type']).to eq('answers')
      expect(json['attempt_number']).to eq(1)
    end
  end

  describe '#question_returned' do
    let(:payload) { { request_id: 'req-1', question_count: 2, attempt_number: 1 } }

    it_behaves_like 'a search log entry', :question_returned, 'question_returned',
                    { request_id: 'req-1', question_count: 2, attempt_number: 1 }

    it 'logs correct fields' do
      logger_instance.question_returned(build_event('question_returned', payload))
      json = parsed_log_output
      expect(json['event']).to eq('question_returned')
      expect(json['question_count']).to eq(2)
      expect(json['attempt_number']).to eq(1)
    end
  end

  describe '#answer_returned' do
    let(:payload) do
      { request_id: 'req-1', answer_count: 3, confidence_levels: { 'strong' => 1, 'good' => 2 }, attempt_number: 2 }
    end

    it_behaves_like 'a search log entry', :answer_returned, 'answer_returned',
                    { request_id: 'req-1',
                      answer_count: 3,
                      confidence_levels: { 'strong' => 1, 'good' => 2 },
                      attempt_number: 2 }

    it 'logs correct fields' do
      logger_instance.answer_returned(build_event('answer_returned', payload))
      json = parsed_log_output
      expect(json['event']).to eq('answer_returned')
      expect(json['answer_count']).to eq(3)
      expect(json['confidence_levels']).to eq({ 'strong' => 1, 'good' => 2 })
      expect(json['attempt_number']).to eq(2)
    end
  end

  describe '#search_completed' do
    let(:payload) do
      { request_id: 'req-1',
        query: 'horses',
        search_type: 'interactive',
        total_attempts: 2,
        total_questions: 1,
        final_result_type: 'answers',
        total_duration_ms: 3000.0,
        result_count: 5 }
    end

    it_behaves_like 'a search log entry', :search_completed, 'search_completed',
                    { request_id: 'req-1',
                      query: 'horses',
                      search_type: 'interactive',
                      total_attempts: 2,
                      total_questions: 1,
                      final_result_type: 'answers',
                      total_duration_ms: 3000.0,
                      result_count: 5 }

    it 'logs correct fields' do
      logger_instance.search_completed(build_event('search_completed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('search_completed')
      expect(json['query']).to eq('horses')
      expect(json['search_type']).to eq('interactive')
      expect(json['total_duration_ms']).to eq(3000.0)
      expect(json['result_count']).to eq(5)
      expect(json['total_attempts']).to eq(2)
    end
  end

  describe '#result_selected' do
    let(:payload) { { request_id: 'req-1', goods_nomenclature_item_id: '4202210000', goods_nomenclature_class: 'Commodity' } }

    it_behaves_like 'a search log entry', :result_selected, 'result_selected',
                    { request_id: 'req-1', goods_nomenclature_item_id: '4202210000', goods_nomenclature_class: 'Commodity' }

    it 'logs correct fields' do
      logger_instance.result_selected(build_event('result_selected', payload))
      json = parsed_log_output
      expect(json['event']).to eq('result_selected')
      expect(json['goods_nomenclature_item_id']).to eq('4202210000')
      expect(json['goods_nomenclature_class']).to eq('Commodity')
    end
  end

  describe '#search_failed' do
    let(:payload) do
      { request_id: 'req-1',
        error_type: 'Faraday::TimeoutError',
        error_message: 'connection timed out',
        search_type: 'interactive' }
    end

    it 'logs at error level with correct fields' do
      logger_instance.search_failed(build_event('search_failed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('search_failed')
      expect(json['error_type']).to eq('Faraday::TimeoutError')
      expect(json['error_message']).to eq('connection timed out')
      expect(json['service']).to eq('search')
    end
  end
end
