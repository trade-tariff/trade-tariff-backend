require 'digest'

# Observes an AI provider call at every boundary that can change its effect:
# the HTTP requests it sends and the timeouts of their connections, retry
# sleeps, log lines, application notifications, and the value or error that
# the caller receives. Specs compare each observation with a JSON snapshot.
#
# The snapshots were recorded from the hand-written OpenAI clients that
# preceded RubyLLM. A passing scenario therefore shows that the current
# implementation sends the same requests and returns the same results.
#
# Record new snapshots with UPDATE_AI_WIRE_CONTRACT=1 in a single process.
# Review every snapshot change: it means a request or a result changed.
module AiWireContract
  OPENAI_BASE_URL = 'https://gb.api.openai.com/v1'.freeze
  RESPONSES_URL = "#{OPENAI_BASE_URL}/responses".freeze
  EMBEDDINGS_URL = "#{OPENAI_BASE_URL}/embeddings".freeze
  SNAPSHOT_DIRECTORY = Rails.root.join('spec/fixtures/ai_wire_contract')

  # Events from frameworks and libraries, including RubyLLM's own events,
  # which have no subscribers in the application.
  IGNORED_EVENTS = /\A(?:!.*|sql\.sequel|.+\.(?:active_support|action_\w+|active_job|rails|ruby_llm))\z/
  ERROR_ATTRIBUTES = %i[status body retry_after response_status reason elapsed_seconds http_status].freeze
  # Request IDs that instrumentation generates when a call has none.
  RANDOM_ID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
  # Sub-nanosecond float rounding in a socket timeout has no effect.
  TIMEOUT_PRECISION = 9

  def observe_ai_call(url:, script:, &)
    Observation.new(self, url:, script:).call(&)
  end

  def expect_wire_contract(file, name, observation)
    actual = JSON.parse(JSON.generate(observation))
    path = SNAPSHOT_DIRECTORY.join("#{file}.json")
    snapshots = path.exist? ? JSON.parse(path.read) : {}

    if ENV['UPDATE_AI_WIRE_CONTRACT'] == '1'
      snapshots[name] = actual
      path.dirname.mkpath
      path.write("#{JSON.pretty_generate(snapshots.sort.to_h)}\n")
    end

    expect(snapshots).to have_key(name), "No snapshot named #{name.inspect}. Record it with UPDATE_AI_WIRE_CONTRACT=1."
    expect(actual).to eq(snapshots.fetch(name))
  end

  # Converts observed values into JSON-compatible data.
  def self.plain(value)
    case value
    when Hash then value.to_h { |key, item| [key.to_s, plain(item)] }
    when Array then plain_array(value)
    when Data, Struct then plain(value.to_h)
    when String then RANDOM_ID.match?(value) ? '<random id>' : value
    when Integer, Float, true, false, nil then value
    when Symbol then value.to_s
    else "#<#{value.class.name}>"
    end
  end

  # Summarises embedding vectors, which are too long to keep in a snapshot.
  def self.plain_array(array)
    if array.size >= 64 && array.all?(Numeric)
      { 'vector_size' => array.size, 'vector_sha256' => Digest::SHA256.hexdigest(JSON.generate(array)) }
    else
      array.map { |item| plain(item) }
    end
  end

  class Observation
    def initialize(example, url:, script:)
      @example = example
      @url = url
      @script = script.dup
      @now = 0.0
      @requests = []
      @connections = []
      @sleeps = []
      @events = []
      @log = StringIO.new
    end

    def call
      install
      outcome = begin
        { 'result' => describe_result(yield) }
      rescue StandardError => e
        { 'error' => describe_error(e) }
      end

      observation.merge(outcome)
    ensure
      ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
    end

  private

    attr_reader :example

    def install
      example.stub_request(:post, @url).to_return { |request| respond(request) }
      example.allow(Net::HTTP).to(example.receive(:new).and_wrap_original do |original, *args|
        original.call(*args).tap { |http| @connections << http }
      end)
      example.allow(Kernel).to example.receive(:sleep) { |seconds|
        @sleeps << seconds
        @now += seconds.to_f
      }
      example.allow(Process).to(example.receive(:clock_gettime).and_wrap_original do |original, *args|
        args == [Process::CLOCK_MONOTONIC] ? @now : original.call(*args)
      end)
      example.allow(Rails).to example.receive(:logger).and_return(logger)
      @subscriber = ActiveSupport::Notifications.subscribe(nil) do |name, _started, _finished, _id, payload|
        @events << [name, AiWireContract.plain(payload)] unless IGNORED_EVENTS.match?(name)
      end
    end

    def logger
      ActiveSupport::Logger.new(@log).tap do |logger|
        logger.level = :debug
        logger.formatter = proc { |severity, _time, _program, message| "#{severity} #{message}\n" }
      end
    end

    def respond(request)
      @requests << describe_request(request)
      step = @script.shift || raise('The provider received an unexpected extra request')
      @now += step.fetch(:duration, 0.0)
      raise step[:raise] if step[:raise]

      step.slice(:status, :headers, :body)
    end

    def describe_request(request)
      {
        'method' => request.method.to_s.upcase,
        'url' => request.uri.to_s,
        'headers' => request.headers.to_h.transform_keys(&:downcase).sort.to_h,
        'body' => parse_json(request.body),
      }
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError, TypeError
      body
    end

    def describe_result(result)
      {
        'class' => result.class.name,
        'value' => AiWireContract.plain(result),
        'ai_usage' => AiWireContract.plain(AiUsage.metadata_from(result)&.to_h),
      }
    end

    def describe_error(error)
      attributes = ERROR_ATTRIBUTES.each_with_object({}) do |name, values|
        values[name.to_s] = AiWireContract.plain(error.public_send(name)) if error.respond_to?(name)
      end

      {
        'class' => error.class.name,
        'message' => error.message,
        'cause' => error.cause&.class&.name,
        'attributes' => attributes,
        'ai_usage' => AiWireContract.plain(error.respond_to?(:ai_usage) ? error.ai_usage&.to_h : nil),
      }
    end

    def observation
      {
        'requests' => @requests,
        'connections' => @connections.map { |http| connection_timeouts(http) },
        'sleeps' => @sleeps,
        'logs' => @log.string.lines.map { |line| line.chomp.gsub(/\d+(?:\.\d+)?(?= seconds)/, 'N') },
        'events' => @events,
        'unused_responses' => @script.size,
      }
    end

    def connection_timeouts(http)
      {
        'open' => http.open_timeout&.to_f&.round(TIMEOUT_PRECISION),
        'read' => http.read_timeout&.to_f&.round(TIMEOUT_PRECISION),
        'write' => http.write_timeout&.to_f&.round(TIMEOUT_PRECISION),
      }
    end
  end

  # Builders for scripted provider responses.
  module Responses
    JSON_HEADERS = { 'Content-Type' => 'application/json' }.freeze
    METADATA_HEADERS = JSON_HEADERS.merge('x-request-id' => 'req_contract', 'openai-processing-ms' => '812').freeze
    USAGE = {
      'input_tokens' => 1_200,
      'input_tokens_details' => { 'cached_tokens' => 1_024 },
      'output_tokens' => 300,
      'output_tokens_details' => { 'reasoning_tokens' => 200 },
      'total_tokens' => 1_500,
    }.freeze

  module_function

    def json(body, status: 200, headers: {}, duration: 0.0)
      { status:, headers: JSON_HEADERS.merge(headers), body: body.is_a?(String) ? body : JSON.generate(body), duration: }
    end

    def raw(body, status:, content_type:, headers: {}, duration: 0.0)
      { status:, headers: { 'Content-Type' => content_type }.merge(headers), body:, duration: }
    end

    def failure(error, duration: 0.0)
      { raise: error, duration: }
    end

    def message(text, type: 'output_text')
      key = type == 'refusal' ? 'refusal' : 'text'
      { 'id' => 'msg_contract',
        'type' => 'message',
        'status' => 'completed',
        'role' => 'assistant',
        'content' => [{ 'type' => type, key => text, 'annotations' => [] }] }
    end

    def reasoning
      { 'id' => 'rs_contract', 'type' => 'reasoning', 'summary' => [] }
    end

    def response_body(status: 'completed', output: [reasoning, message('{"capital":"Paris"}')], usage: USAGE, **fields)
      {
        'id' => 'resp_contract',
        'object' => 'response',
        'status' => status,
        'model' => 'gpt-5.2-2025-12-11',
        'service_tier' => 'default',
        'output' => output,
        'usage' => usage,
      }.merge(fields.transform_keys(&:to_s)).compact
    end

    def completed(text = '{"capital":"Paris"}', duration: 0.0, headers: METADATA_HEADERS, **fields)
      json(response_body(output: [reasoning, message(text)], **fields), headers:, duration:)
    end

    def embeddings(count, indices: (0...count).to_a, dimensions: 1536, usage: { 'prompt_tokens' => 8 * count, 'total_tokens' => 8 * count }, headers: METADATA_HEADERS, **fields)
      data = indices.map do |index|
        { 'object' => 'embedding', 'index' => index, 'embedding' => Array.new(dimensions) { |position| ((index + 1) * 0.001) + (position * 1.0e-6) } }
      end

      json({ 'object' => 'list', 'data' => data, 'model' => 'text-embedding-3-small', 'usage' => usage }.merge(fields.transform_keys(&:to_s)).compact, headers:)
    end
  end
end

RSpec.configure do |config|
  config.include AiWireContract, :ai_wire_contract
end
