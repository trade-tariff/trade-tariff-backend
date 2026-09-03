# frozen_string_literal: true

require 'stringio'

RSpec.describe 'search degradation log alarms' do
  subject(:terraform) { Rails.root.join('terraform/degradation_alarms.tf').read }

  def alarm_pattern(alarm_key)
    block = terraform[/#{Regexp.escape(alarm_key)} = \{.*?^\s{4}\}/m]
    raise "missing terraform alarm block for #{alarm_key}" if block.blank?

    raw = block[/pattern\s+=\s+"((?:\\.|[^"\\])*)"/, 1]
    raise "missing pattern for #{alarm_key}" if raw.blank?

    raw.gsub('\"', '"')
  end

  def matches_alarm?(alarm_key, event)
    CloudWatchJsonFilter.matches?(alarm_pattern(alarm_key), event)
  end

  def search_log(method_name, payload)
    log_output = StringIO.new
    logger_instance = Search::Logger.new.tap do |instance|
      test_logger = ActiveSupport::Logger.new(log_output)
      instance.define_singleton_method(:logger) { test_logger }
    end

    logger_instance.public_send(
      method_name,
      ActiveSupport::Notifications::Event.new(
        "#{method_name}.search",
        Time.current,
        Time.current,
        SecureRandom.hex(10),
        payload,
      ),
    )

    log_output.rewind
    JSON.parse(log_output.read.strip.split("\n").last)
  end

  it 'gates metric filters and alarms on enable_alarms' do
    expect(terraform).to include('for_each = var.enable_alarms ? local.search_degradation_alarms : {}')
    expect(terraform.scan('for_each = var.enable_alarms ? local.search_degradation_alarms : {}').size).to eq(2)
  end

  it 'routes aggregated alarms to Slack without per-request notifiers' do
    expect(terraform).to include('alarm_actions = [data.aws_sns_topic.slack_topic.arn]')
    expect(terraform).to include('treat_missing_data  = "notBreaching"')
    expect(terraform).to include('namespace = "TradeTariff/Search"')
    expect(terraform).not_to include('Http5xxCount')
    expect(terraform).not_to include('tariff_sync')
    expect(terraform).not_to include('SidekiqJobFailCount')
  end

  it 'includes owner, first action, and request_id tracing in every alarm description' do
    descriptions = terraform.scan(/alarm_description\s+=\s+"([^"]+)"/).flatten

    expect(descriptions.size).to eq(4)
    expect(descriptions).to all(include('Owner: Trade Tariff search'))
    expect(descriptions).to all(include('First action:'))
    expect(descriptions).to all(include('request_id'))
    expect(descriptions).to all(include('${var.environment}'))
    expect(descriptions).to all(include('${local.search_operations_dashboard}'))
  end

  it 'matches Search::Logger search_failed events and ignores completed searches' do
    failed = search_log(
      :search_failed,
      request_id: 'req-1',
      error_type: 'Faraday::TimeoutError',
      error_message: 'connection timed out',
      search_type: 'interactive',
    )
    completed = search_log(
      :search_completed,
      request_id: 'req-1',
      query: 'horses',
      search_type: 'interactive',
      result_count: 3,
      final_result_type: 'answers',
      total_duration_ms: 12,
    )

    expect(failed).to include('service' => 'search', 'event' => 'search_failed', 'request_id' => 'req-1', 'error_type' => 'Faraday::TimeoutError')
    expect(matches_alarm?('search_failed', failed)).to be(true)
    expect(matches_alarm?('search_failed', completed)).to be(false)
    expect(matches_alarm?('interactive_search_error', completed)).to be(false)
  end

  it 'matches interactive search completions that finished as errors' do
    errored = search_log(
      :search_completed,
      request_id: 'req-2',
      query: 'tea',
      search_type: 'interactive',
      result_count: 0,
      final_result_type: 'error',
      error_message: 'model returned error',
      total_duration_ms: 40,
    )

    expect(errored).to include('event' => 'search_completed', 'final_result_type' => 'error', 'error_message' => 'model returned error')
    expect(matches_alarm?('interactive_search_error', errored)).to be(true)
    expect(matches_alarm?('search_failed', errored)).to be(false)
  end

  it 'matches failed OpenSearch or vector retrieval legs and ignores successful legs' do
    failed_leg = search_log(
      :retrieval_leg_completed,
      request_id: 'req-3',
      search_type: 'interactive',
      leg: 'vector',
      duration_ms: 120.5,
      result_count: 0,
      status: 'error',
      error_message: 'vector down',
    )
    successful_leg = search_log(
      :retrieval_leg_completed,
      request_id: 'req-3',
      search_type: 'interactive',
      leg: 'lexical',
      duration_ms: 40.0,
      result_count: 8,
      status: 'success',
    )

    expect(failed_leg).to include('event' => 'retrieval_leg_completed', 'status' => 'error', 'leg' => 'vector')
    expect(matches_alarm?('retrieval_leg_error', failed_leg)).to be(true)
    expect(matches_alarm?('retrieval_leg_error', successful_leg)).to be(false)
  end

  it 'matches AI query-expansion timeouts and ignores successful expansions' do
    timed_out = search_log(
      :query_expansion_timed_out,
      request_id: 'req-4',
      search_type: 'interactive',
      timeout_ms: 5000,
      elapsed_ms: 5120.2,
      model: 'gpt-5-mini',
      fallback_outcome: 'original_query',
    )
    expanded = search_log(
      :query_expanded,
      request_id: 'req-4',
      search_type: 'interactive',
      original_query: 'tea',
      expanded_query: 'tea leaves',
      reason: 'synonym',
      duration_ms: 80,
    )

    expect(timed_out).to include('event' => 'query_expansion_timed_out', 'fallback_outcome' => 'original_query', 'request_id' => 'req-4')
    expect(matches_alarm?('query_expansion_timed_out', timed_out)).to be(true)
    expect(matches_alarm?('query_expansion_timed_out', expanded)).to be(false)
  end
end
