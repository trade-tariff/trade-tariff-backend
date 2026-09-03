# frozen_string_literal: true

require 'stringio'
require_relative '../../config/environments/production_environment_config'

RSpec.describe 'degradation log alarms' do
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

  def lograge_event(status:)
    exception = status >= 500 ? StandardError.new('boom') : nil
    notification = instance_double(
      ActiveSupport::Notifications::Event,
      payload: {
        request_id: 'req-1',
        auth_type: 'token',
        client_id: 'client',
        headers: { 'HTTP_ACCEPT' => 'application/json' },
        exception_object: exception,
        exception: exception && [exception.class.name, exception.message],
        params: { 'id' => '0101210000' },
        user_agent: 'rspec',
      },
    )

    data = {
      method: 'GET',
      path: '/uk/api/v2/commodities/0101210000',
      format: 'json',
      controller: 'api/v2/commodities',
      action: 'show',
      status: status,
      duration: 12.3,
    }.merge(ProductionEnvironmentConfig.lograge_custom_options.call(notification))

    JSON.parse(Lograge::Formatters::Logstash.new.call(data))
  end

  def search_log(method_name, payload)
    parsed_logger_json(Search::Logger, method_name, "#{method_name}.search", payload)
  end

  def sync_log(method_name, payload)
    parsed_logger_json(TariffSynchronizer::SyncLogger, method_name, "#{method_name}.tariff_sync", payload)
  end

  def parsed_logger_json(logger_class, method_name, event_name, payload)
    log_output = StringIO.new
    logger_instance = logger_class.new.tap do |instance|
      test_logger = ActiveSupport::Logger.new(log_output)
      instance.define_singleton_method(:logger) { test_logger }
    end

    logger_instance.public_send(
      method_name,
      ActiveSupport::Notifications::Event.new(
        event_name,
        Time.current,
        Time.current,
        SecureRandom.hex(10),
        payload,
      ),
    )

    log_output.rewind
    JSON.parse(log_output.read.strip.split("\n").last)
  end

  def failed_sidekiq_job_log
    item = {
      'retry' => false,
      'queue' => 'default',
      'args' => ['search', 'CommodityIndex', 10],
      'class' => 'BuildIndexPageWorker',
      'jid' => '11a54a43f3130a57c845350f',
    }

    log_output = StringIO.new
    sidekiq_logger = Sidekiq::Logger.new(log_output)
    sidekiq_logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    allow(Sidekiq).to receive(:logger).and_return(sidekiq_logger)

    expect {
      CustomJobLogger.new(Sidekiq::Config.new).call(item, 'default') do
        raise StandardError, 'Something went wrong'
      end
    }.to raise_error(StandardError, 'Something went wrong')

    log_output.rewind
    JSON.parse(log_output.read.strip.split("\n").last)
  end

  def successful_sidekiq_job_log
    item = {
      'retry' => false,
      'queue' => 'default',
      'args' => ['search', 'CommodityIndex', 10],
      'class' => 'BuildIndexPageWorker',
      'jid' => '11a54a43f3130a57c845350f',
    }

    log_output = StringIO.new
    sidekiq_logger = Sidekiq::Logger.new(log_output)
    sidekiq_logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    allow(Sidekiq).to receive(:logger).and_return(sidekiq_logger)

    CustomJobLogger.new(Sidekiq::Config.new).call(item, 'default') { true }

    log_output.rewind
    JSON.parse(log_output.read.strip.split("\n").last)
  end

  it 'gates metric filters and alarms on enable_alarms' do
    expect(terraform).to include('for_each = var.enable_alarms ? local.degradation_log_alarms : {}')
    expect(terraform.scan('for_each = var.enable_alarms ? local.degradation_log_alarms : {}').size).to eq(2)
  end

  it 'routes alarms to the production Slack topic' do
    expect(terraform).to include('alarm_actions = [data.aws_sns_topic.slack_topic.arn]')
    expect(terraform).to include('treat_missing_data  = "notBreaching"')
    expect(terraform).to include('namespace = "TradeTariff/Backend"')
  end

  it 'includes owner and first action in every alarm description' do
    descriptions = terraform.scan(/alarm_description\s+=\s+"([^"]+)"/).flatten

    expect(descriptions.size).to eq(6)
    expect(descriptions).to all(include('Owner: Trade Tariff backend'))
    expect(descriptions).to all(include('First action:'))
    expect(descriptions).to all(include('${var.environment}'))
  end

  it 'matches lograge 5xx request logs and ignores successful requests' do
    expect(matches_alarm?('http_5xx', lograge_event(status: 500))).to be(true)
    expect(matches_alarm?('http_5xx', lograge_event(status: 503))).to be(true)
    expect(matches_alarm?('http_5xx', lograge_event(status: 200))).to be(false)
    expect(matches_alarm?('http_5xx', lograge_event(status: 404))).to be(false)
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
      duration_ms: 12,
    )

    expect(failed['service']).to eq('search')
    expect(failed['event']).to eq('search_failed')
    expect(matches_alarm?('search_failed', failed)).to be(true)
    expect(matches_alarm?('search_failed', completed)).to be(false)
    expect(matches_alarm?('http_5xx', failed)).to be(false)
  end

  it 'matches tariff sync failure events and ignores a successful run' do
    run_failed = sync_log(
      :sync_run_failed,
      service: 'uk',
      run_id: 'run-1',
      phase: 'download',
      error_class: 'RuntimeError',
      error_message: 'boom',
    )
    sequence_failed = sync_log(
      :sequence_check_failed,
      service: 'uk',
      run_id: 'run-1',
      details: 'pending 2, applied 1',
    )
    failed_updates = sync_log(
      :failed_updates_detected,
      service: 'uk',
      run_id: 'run-1',
      filenames: ['taric-1.xml'],
    )
    completed = sync_log(
      :sync_run_completed,
      service: 'uk',
      run_id: 'run-1',
      duration_ms: 5000.0,
      files_downloaded: 3,
      files_applied: 2,
    )

    expect(matches_alarm?('tariff_sync_run_failed', run_failed)).to be(true)
    expect(matches_alarm?('tariff_sequence_check_failed', sequence_failed)).to be(true)
    expect(matches_alarm?('tariff_failed_updates', failed_updates)).to be(true)
    expect(matches_alarm?('tariff_sync_run_failed', completed)).to be(false)
    expect(matches_alarm?('tariff_sequence_check_failed', completed)).to be(false)
    expect(matches_alarm?('tariff_failed_updates', completed)).to be(false)
  end

  it 'matches CustomJobLogger failures through the production Sidekiq JSON formatter' do
    failed = failed_sidekiq_job_log
    succeeded = successful_sidekiq_job_log

    expect(failed.dig('msg', 'status')).to eq('fail')
    expect(failed.dig('msg', 'class')).to eq('BuildIndexPageWorker')
    expect(matches_alarm?('sidekiq_job_fail', failed)).to be(true)
    expect(matches_alarm?('sidekiq_job_fail', succeeded)).to be(false)
  end
end
