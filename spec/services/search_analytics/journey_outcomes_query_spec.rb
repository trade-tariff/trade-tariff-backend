RSpec.describe SearchAnalytics::JourneyOutcomesQuery do
  let(:db) { Sequel::Model.db }
  let(:columns) do
    { request_id: 'text',
      service: 'text',
      event: 'text',
      search_type: 'text',
      result_count: 'bigint',
      final_result_type: 'text',
      results_type: 'text',
      commodity_result_count: 'bigint',
      search_degraded: 'boolean',
      total_questions: 'bigint',
      '@timestamp': 'timestamp' }
  end

  def event(id, type, **attributes)
    { request_id: id,
      service: 'search',
      event: 'search_completed',
      search_type: type,
      result_count: 1,
      final_result_type: nil,
      results_type: 'hybrid',
      commodity_result_count: nil,
      search_degraded: false,
      total_questions: nil,
      '@timestamp': Time.utc(2026, 9, 14, 12) }.merge(attributes)
  end

  def execute(*events)
    values = events.map { |row| "(#{columns.map { |name, type| "#{db.literal(row.fetch(name))}::#{type}" }.join(', ')})" }
    source = "(VALUES #{values.join(', ')}) AS source_events(#{columns.keys.map { |name| db.literal(Sequel.identifier(name)) }.join(', ')})"
    canonical = SearchAnalytics::CloudwatchSnapshotQuery.new(period: '24h', client: nil).send(:zero_result_condition)
    sql = described_class.call(source:, log_stream_filter: 'TRUE', zero_result_condition: canonical)
    # Execute the real predicates and grouping in PostgreSQL. Only identifier
    # quoting and the equivalent distinct-array aggregate differ from CloudWatch.
    sql = sql.tr('`', '"').gsub('COLLECT_SET(', 'ARRAY_AGG(DISTINCT ')
    db.fetch(sql).each_with_object({}) do |row, result|
      JSON.parse(row.fetch(:request_ids).to_s).each { |id| result[id] = row.except(:request_ids) }
    end
  end

  it 'keeps the backend question count from the completed search event' do
    rows = execute(event('one', 'interactive', total_questions: 4, final_result_type: 'answers'))
    expect(rows.fetch('one')[:total_questions]).to eq(4)
  end

  it 'recognises classification, exact, empty retrieval and fallback results but not question steps' do
    rows = execute(
      event('classification', 'classification', result_count: 0),
      event('exact', 'interactive', results_type: 'exact_match'),
      event('empty', 'internal', result_count: 0),
      event('fallback', 'interactive', final_result_type: 'error', search_degraded: true),
      event('question', 'interactive', final_result_type: 'questions'),
    )
    expect(rows.values_at('classification', 'exact', 'empty', 'fallback').map { |row| row[:terminal_state] }).to all(eq('completed'))
    expect(rows.fetch('classification')[:zero_result]).to eq(1)
    expect(rows.fetch('question')).to include(terminal_state: 'none', questions_seen: 1, zero_result: 0)
  end

  it 'uses empty-commodity semantics for Classic and does not call degraded empty responses zero results' do
    rows = execute(
      event('headings', 'classic', result_count: 2, commodity_result_count: 0, results_type: 'fuzzy_search'),
      event('exact', 'classic', commodity_result_count: 0, results_type: 'exact_search'),
      event('legacy-empty', 'classic', result_count: 0),
      event('degraded', 'interactive', result_count: 0, final_result_type: 'error', search_degraded: true),
    )
    expect(rows.fetch('headings')[:zero_result]).to eq(1)
    expect(rows.fetch('legacy-empty')[:zero_result]).to eq(1)
    expect(rows.values_at('exact', 'degraded').map { |row| row[:zero_result] }).to eq([0, 0])
  end

  it 'resolves terminal chronology and equal-time conflicts without treating stage errors as terminal failures' do
    rows = execute(
      event('recovered', 'interactive', event: 'search_failed'),
      event('recovered', 'interactive', final_result_type: 'answers', '@timestamp': Time.utc(2026, 9, 14, 13)),
      event('conflict', 'classic'), event('conflict', 'classic', event: 'search_failed'),
      event('stage-only', 'interactive', event: 'search_stage_failed')
    )
    expect(rows.fetch('recovered')[:terminal_state]).to eq('completed')
    expect(rows.fetch('conflict')[:terminal_state]).to eq('conflict')
    expect(rows).not_to have_key('stage-only')
  end
end
