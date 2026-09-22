require 'stringio'

RSpec.describe Search::Metrics do
  subject(:record) { described_class.record(event, output:, environment: 'production', service: 'uk', now:) }

  let(:output) { StringIO.new }
  let(:now) { Time.utc(2026, 9, 22, 12) }
  let(:event) { ActiveSupport::Notifications::Event.new('search_completed.search', now, now, 'id', payload) }
  let(:payload) do
    {
      request_source: 'frontend',
      search_type: 'classic',
      total_duration_ms: 1500,
      result_count: 4,
      commodity_result_count: 2,
      results_type: 'fuzzy_search',
    }
  end
  let(:emitted) { JSON.parse(output.string) }

  def dimension_sets(metric_name)
    emitted.dig('_aws', 'CloudWatchMetrics')
      .find { |definition| definition.dig('Metrics', 0, 'Name') == metric_name }
      .fetch('Dimensions')
  end

  it 'emits a completed search without request identifiers as dimensions' do
    expect(record).to be(true)
    expect(emitted).to include(
      'Environment' => 'production',
      'Service' => 'uk',
      'RequestSource' => 'frontend',
      'SearchType' => 'classic',
      'Outcome' => 'completed',
      'SearchEvents' => 1,
      'SearchDuration' => 1.5,
      'ResultCount' => 4,
      'CommodityResultCount' => 2,
    )
    expect(emitted).not_to have_key('EmptyResults')
    expect(emitted.dig('_aws', 'Timestamp')).to eq((now.to_f * 1000).to_i)
    expect(emitted.dig('_aws', 'CloudWatchMetrics').map { |definition| definition['Namespace'] }.uniq).to eq(['TradeTariff/Search'])
    expect(emitted.dig('_aws', 'CloudWatchMetrics').flat_map { |definition| definition['Dimensions'].flatten }).not_to include('request_id')
    expect(dimension_sets('SearchEvents')).to eq([
      %w[Environment Service RequestSource Outcome],
      %w[Environment Service SearchType Outcome],
      %w[Environment Service Outcome],
    ])
    expect(dimension_sets('SearchDuration')).to eq([%w[Environment Service]])
  end

  it 'counts a classic fuzzy search with zero commodity hits as empty' do
    payload[:commodity_result_count] = 0

    record

    expect(emitted['EmptyResults']).to eq(1)
    expect(emitted['CommodityResultCount']).to eq(0)
  end

  it 'does not count an exact classic match with zero commodity hits as empty' do
    payload[:commodity_result_count] = 0
    payload[:results_type] = 'exact_search'

    record

    expect(emitted).not_to have_key('EmptyResults')
  end

  it 'does not count an exact classic match when the result type is a symbol' do
    payload[:commodity_result_count] = 0
    payload[:results_type] = :exact_search

    record

    expect(emitted).not_to have_key('EmptyResults')
  end

  it 'counts a classic zero commodity result when the result type is omitted' do
    payload.delete(:results_type)
    payload[:commodity_result_count] = 0

    record

    expect(emitted['EmptyResults']).to eq(1)
  end

  it 'does not treat missing counts as empty' do
    payload.delete(:commodity_result_count)
    payload.delete(:result_count)

    record

    expect(emitted).not_to have_key('EmptyResults')

    output.truncate(0)
    output.rewind
    described_class.record(
      ActiveSupport::Notifications::Event.new(
        'search_completed.search', now, now, 'id',
        payload.merge(search_type: 'interactive', result_count: nil)
      ),
      output:, environment: 'production', service: 'uk', now:,
    )
    expect(JSON.parse(output.string)).not_to have_key('EmptyResults')
  end

  it 'keeps the search event when a duration or count is not finite' do
    payload[:total_duration_ms] = Float::NAN
    payload[:result_count] = Float::INFINITY

    record

    expect(emitted['SearchEvents']).to eq(1)
    expect(emitted).not_to have_key('SearchDuration')
    expect(emitted).not_to have_key('ResultCount')
  end

  it 'counts a classic search with no commodity count and zero results as empty' do
    payload.delete(:commodity_result_count)
    payload[:result_count] = 0

    record

    expect(emitted['EmptyResults']).to eq(1)
    expect(emitted).not_to have_key('CommodityResultCount')
  end

  it 'counts interactive and internal zero-result searches, but not other types' do
    %w[interactive internal].each do |search_type|
      output.truncate(0)
      output.rewind
      described_class.record(
        ActiveSupport::Notifications::Event.new('search_completed.search', now, now, 'id', payload.merge(search_type:, result_count: 0)),
        output:, environment: 'production', service: 'uk', now:,
      )
      expect(JSON.parse(output.string)['EmptyResults']).to eq(1)
    end

    output.truncate(0)
    output.rewind
    described_class.record(
      ActiveSupport::Notifications::Event.new('search_completed.search', now, now, 'id', payload.merge(search_type: 'classification', result_count: 0)),
      output:, environment: 'production', service: 'uk', now:,
    )
    expect(JSON.parse(output.string)).not_to have_key('EmptyResults')
  end

  it 'records a failed search without duration or result counts' do
    event_name = 'search_failed.search'
    failed = ActiveSupport::Notifications::Event.new(event_name, now, now, 'id', { search_type: 'interactive' })

    described_class.record(failed, output:, environment: 'staging', service: 'xi', now:)

    expect(emitted).to include('Outcome' => 'failed', 'SearchType' => 'interactive', 'RequestSource' => 'unknown', 'SearchEvents' => 1)
    expect(emitted).not_to have_key('SearchDuration')
  end

  it 'collapses unexpected labels and ignores unrelated events' do
    payload[:request_source] = 'browser-extension'
    payload[:search_type] = 'horse'

    record

    expect(emitted).to include('RequestSource' => 'other', 'SearchType' => 'other')

    output.truncate(0)
    output.rewind
    ignored = ActiveSupport::Notifications::Event.new('search_started.search', now, now, 'id', payload)
    expect(described_class.record(ignored, output:, environment: 'production', service: 'uk', now:)).to be(false)
    expect(output.string).to eq('')
  end

  it 'emits selection, expansion, and AI call metrics in seconds' do
    described_class.record(
      ActiveSupport::Notifications::Event.new('result_selected.search', now, now, 'id', {}),
      output:, environment: 'production', service: 'uk', now:,
    )
    described_class.record(
      ActiveSupport::Notifications::Event.new('query_expanded.search', now, now, 'id', {}),
      output:, environment: 'production', service: 'uk', now:,
    )
    described_class.record(
      ActiveSupport::Notifications::Event.new('api_call_completed.search', now, now, 'id', { duration_ms: 250 }),
      output:, environment: 'production', service: 'uk', now:,
    )

    lines = output.string.lines.map { |line| JSON.parse(line) }
    expect(lines.map { |line| line.except('_aws', 'Environment', 'Service') }).to eq([
      { 'ResultSelections' => 1 },
      { 'QueryExpansions' => 1 },
      { 'AiApiDuration' => 0.25 },
    ])
    expect(lines.last.dig('_aws', 'CloudWatchMetrics', 0, 'Metrics', 0)).to include('Name' => 'AiApiDuration', 'Unit' => 'Seconds')
  end

  it 'drops a failed write instead of raising' do
    failing = instance_double(IO)
    allow(failing).to receive(:write_nonblock).and_raise(IOError)

    expect(described_class.record(event, output: failing, environment: 'production', service: 'uk', now:)).to be(false)
  end

  it 'drops a blocked, short, or oversized write' do
    blocked = instance_double(IO)
    allow(blocked).to receive(:write_nonblock).and_return(:wait_writable)
    expect(described_class.record(event, output: blocked, environment: 'production', service: 'uk', now:)).to be(false)

    short = instance_double(IO)
    allow(short).to receive(:write_nonblock).and_return(1)
    expect(described_class.record(event, output: short, environment: 'production', service: 'uk', now:)).to be(false)

    allow(JSON).to receive(:generate).and_return('x' * described_class::MAX_LINE_BYTES)
    expect(output).not_to receive(:write_nonblock)
    expect(record).to be(false)
  end

  it 'subscribes to search notifications and can be removed' do
    buffer = StringIO.new
    described_class.subscribe!(output: buffer)
    ActiveSupport::Notifications.instrument('query_expanded.search', {})
    described_class.unsubscribe!
    ActiveSupport::Notifications.instrument('query_expanded.search', {})

    expect(buffer.string.lines.size).to eq(1)
  ensure
    described_class.unsubscribe!
  end

  it 'keeps one subscription when the class state is discarded' do
    buffer = StringIO.new
    described_class.subscribe!(output: buffer)
    expect(Rails.application.config.x.search_metrics_subscriber).to be_present
    described_class.singleton_class.remove_instance_variable(:@subscriber) if described_class.singleton_class.instance_variable_defined?(:@subscriber)

    described_class.subscribe!(output: buffer)
    ActiveSupport::Notifications.instrument('query_expanded.search', {})

    expect(buffer.string.lines.size).to eq(1)
  ensure
    described_class.unsubscribe!
  end
end
