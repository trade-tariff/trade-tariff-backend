require 'stringio'

RSpec.describe Search::Metrics do
  let(:output) { StringIO.new }
  let(:now) { Time.utc(2026, 9, 22, 12) }

  def emit(name, service:, attributes: {}, timestamp: now)
    event = ActiveSupport::Notifications::Event.new("#{name}.search", timestamp, timestamp, 'notification', attributes)
    described_class.record(event, output:, environment: 'production', service:, now: timestamp)
  end

  def samples
    output.string.lines.map { |line| JSON.parse(line) }
  end

  it 'keeps repeated events, missing identities, all search types and degraded completions in hourly counts' do
    emit('search_completed', service: 'uk', attributes: { request_id: 'repeat', search_type: 'classic' })
    emit('search_completed', service: 'xi', attributes: { request_id: 'repeat', search_type: 'classic' })
    emit('search_completed', service: 'uk', attributes: { search_type: 'evaluation', search_degraded: true })
    emit('search_failed', service: 'xi', attributes: { request_id: 'repeat' })
    emit('result_selected', service: 'xi', attributes: { request_id: 'repeat' })
    emit('result_selected', service: 'xi', attributes: { request_id: 'repeat' })
    emit('result_selected', service: 'uk')
    emit('search_completed', service: 'uk', timestamp: now + 1.hour)

    completed = samples.select { |sample| sample['Outcome'] == 'completed' }
    hourly = completed.group_by { |sample| sample.dig('_aws', 'Timestamp') / 3_600_000 }
    expect(hourly.values.map { |group| group.sum { |sample| sample.fetch('SearchEvents') } }).to eq([3, 1])
    expect(samples.sum { |sample| sample.fetch('ResultSelections', 0) }).to eq(3)
    expect(completed.flat_map { |sample| sample.dig('_aws', 'CloudWatchMetrics') }
      .select { |definition| definition.dig('Metrics', 0, 'Name') == 'SearchEvents' }
      .map { |definition| definition.fetch('Dimensions').count(%w[Environment Service Outcome]) }).to all(eq(1))
  end

  it 'keeps empty-result categories separate while allowing UK and XI counts to be added' do
    %w[uk xi].each do |service|
      emit('search_completed', service:, attributes: { search_type: 'classic', commodity_result_count: 0, result_count: 3, results_type: 'fuzzy_search' })
      emit('search_completed', service:, attributes: { search_type: 'classic', result_count: 0 })
      emit('search_completed', service:, attributes: { search_type: 'classic', commodity_result_count: 0, result_count: 0, results_type: 'exact_search' })
      emit('search_completed', service:, attributes: { search_type: 'interactive', result_count: 0 })
      emit('search_completed', service:, attributes: { search_type: 'internal', result_count: 0 })
      emit('search_completed', service:, attributes: { search_type: 'interactive' })
      emit('search_completed', service:, attributes: { search_type: 'evaluation', result_count: 0 })
    end

    empty = samples.select { |sample| sample.key?('EmptyResults') }
    totals = empty.group_by { |sample| sample.fetch('SearchType') }.transform_values { |group| group.sum { |sample| sample.fetch('EmptyResults') } }
    expect(totals).to eq('classic' => 4, 'interactive' => 2, 'internal' => 2)
    expect(empty.flat_map { |sample| sample.dig('_aws', 'CloudWatchMetrics') }
      .select { |definition| definition.dig('Metrics', 0, 'Name') == 'EmptyResults' }
      .map { |definition| definition.fetch('Dimensions') }).to all(eq([%w[Environment Service SearchType]]))
  end

  it 'keeps invalid supplied counts out of empty-result rollups' do
    invalid_counts = ['bad', '0', '', true, false, -1, Float::NAN, Float::INFINITY]
    invalid_counts.each do |count|
      emit('search_completed', service: 'uk', attributes: {
        search_type: 'classic',
        commodity_result_count: count,
        result_count: 0,
        results_type: 'fuzzy_search',
      })
      emit('search_completed', service: 'xi', attributes: { search_type: 'interactive', result_count: count })
      emit('search_completed', service: 'uk', attributes: { search_type: 'internal', result_count: count })
    end
    emit('search_completed', service: 'uk', attributes: { search_type: 'classic', result_count: 0, results_type: 'exact_search' })
    emit('search_completed', service: 'xi', attributes: { search_type: 'classic', commodity_result_count: 0, result_count: 2, results_type: 'fuzzy_search' })

    empty = samples.select { |sample| sample.key?('EmptyResults') }
    expect(samples.count { |sample| sample['SearchEvents'] == 1 }).to eq((invalid_counts.size * 3) + 2)
    expect(empty.sum { |sample| sample.fetch('EmptyResults') }).to eq(2)
    expect(empty.map { |sample| sample.fetch('SearchType') }).to contain_exactly('classic', 'classic')
  end
end
