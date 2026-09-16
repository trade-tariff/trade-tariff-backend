RSpec.describe SearchAnalytics::JourneyOutcomes do
  let(:date) { Date.new(2026, 9, 14) }
  let(:period) { SearchAnalytics::Period.for(period: '24h', view: 'internal') }
  let(:records) { SearchAnalyticsQueryResult.where(service: TradeTariffBackend.service, name: 'journey_outcomes', fingerprint: 'outcomes-v1') }

  def starts(keys, time: '2026-09-14T08:00:00Z', source: 'frontend', type: 'interactive')
    { '@timestamp' => time, 'request_source' => source, 'search_type' => type, 'journey_keys' => keys }
  end

  def window(keys, kind: 'none', until_time: '2026-09-14T12:00:00Z', **flags)
    { 'journey_keys' => keys,
      'terminal_state' => kind,
      'window_end' => until_time,
      'selected' => '0',
      'zero_result' => '0',
      'questions_seen' => '0',
      'unknown_seen' => '0' }.merge(flags.stringify_keys)
  end

  def store(rows, day: date)
    SearchAnalyticsQueryResult.create(service: TradeTariffBackend.service, reporting_date: day, name: 'journey_outcomes', fingerprint: 'outcomes-v1', rows: Sequel.pg_jsonb(rows), collected_at: Time.utc(2026, 9, 16))
  end

  def outcomes(start_rows, dates: [date], selected_period: period)
    journeys = SearchAnalytics::JourneyMetrics.new(rows: start_rows, period: selected_period)
    described_class.call(journeys:, records:, dates:, buckets: journeys.keys_by_bucket.keys)
  end

  it 'joins only selected frontend IDs, deduplicates steps and distinguishes questions from unknown outcomes' do
    store([
      window(%w[one two], questions_seen: '1'),
      window(%w[one admin other-mode], kind: 'completed', selected: '1', until_time: '2026-09-14T15:00:00Z'),
    ])
    result = outcomes([starts(%w[one two missing]), starts(%w[admin], source: 'admin'), starts(%w[other-mode], type: 'classic')])
    expect(result['summary']).to eq('completed' => 1, 'failed' => 0, 'nonterminal' => 1, 'unknown' => 1, 'selected' => 1, 'zero_result' => 0)
    expect(result['trend'].first.except('bucket')).to eq(result['summary'])
    expect(result.to_json).not_to include('other-mode', 'journey_keys')
  end

  it 'uses the latest terminal window, independent of row order, and permits recovery' do
    store([
      window(%w[one], kind: 'completed', until_time: '2026-09-14T15:00:00Z'),
      window(%w[one], kind: 'failed'),
      window(%w[one], questions_seen: '1', until_time: '2026-09-14T18:00:00Z'),
    ])
    expect(outcomes([starts(%w[one])])['summary']).to include('completed' => 1, 'failed' => 0, 'nonterminal' => 0)
  end

  it 'produces the same outcomes when a collection window is split' do
    store([window(%w[one], kind: 'completed', selected: '1', zero_result: '1', until_time: '2026-09-14T15:00:00Z')])
    unsplit = outcomes([starts(%w[one])])
    records.delete
    store([
      window(%w[one], kind: 'failed', selected: '1', until_time: '2026-09-14T13:30:00Z'),
      window(%w[one], kind: 'completed', zero_result: '1', until_time: '2026-09-14T15:00:00Z'),
    ])
    expect(outcomes([starts(%w[one])])).to eq(unsplit)
  end

  it 'does not hide a later failure behind an earlier completion' do
    store([window(%w[one], kind: 'completed'), window(%w[one], kind: 'failed', until_time: '2026-09-14T15:00:00Z')])
    expect(outcomes([starts(%w[one])])['summary']).to include('failed' => 1, 'completed' => 0)
  end

  it 'keeps selections and empty-result observations as overlapping distinct-journey indicators' do
    store([window(%w[one], kind: 'completed', zero_result: '1'), window(%w[one], selected: '1'), window(%w[one], selected: '1')])
    result = outcomes([starts(%w[one])])['summary']
    expect(result).to include('completed' => 1, 'zero_result' => 1, 'selected' => 1)
    expect(result.values_at('completed', 'failed', 'nonterminal', 'unknown').sum).to eq(1)
  end

  it 'surfaces conflicting and unrecognised outcomes as unknown, not successful or question-only' do
    store([window(%w[one], kind: 'conflict'), window(%w[two], questions_seen: '1', unknown_seen: '1')])
    expect(outcomes([starts(%w[one two])])['summary']).to include('unknown' => 2, 'completed' => 0, 'nonterminal' => 0)
  end

  it 'does not pick an arbitrary winner when duplicate window states conflict' do
    store([window(%w[one], kind: 'completed'), window(%w[one], kind: 'failed')])
    expect(outcomes([starts(%w[one])])['summary']['unknown']).to eq(1)
  end

  it 'attributes a next-day completion to existing start buckets and deduplicates the range total' do
    store([], day: date - 1)
    store([window(%w[one], kind: 'completed')])
    start_rows = [starts(%w[one], time: '2026-09-13T23:00:00Z'), starts(%w[one])]
    result = outcomes(start_rows, dates: [date - 1, date], selected_period: SearchAnalytics::Period.for(period: '7d', view: 'internal'))
    expect(result['summary']['completed']).to eq(1)
    expect(result['trend'].map { |row| [row['bucket'], row['completed']] }).to eq([['2026-09-13T00:00:00Z', 1], ['2026-09-14T00:00:00Z', 1]])
  end

  it 'does not fetch or use an outcome outside the selected dates' do
    store([])
    store([window(%w[one], kind: 'completed', until_time: '2026-09-15T03:00:00Z')], day: date + 1)
    expect(outcomes([starts(%w[one])])['summary']).to include('unknown' => 1, 'completed' => 0)
  end

  it 'withholds outcomes while collection is incomplete rather than fabricating unknown journeys' do
    result = outcomes([starts(%w[one])])
    expect(result).to include('summary' => nil, 'trend' => [])
    expect(result['coverage']).to include('complete' => false, 'missing_dates' => [date.iso8601])
  end

  it 'reports a successful empty collection as complete with unknown outcomes for recorded starts' do
    store([])
    result = outcomes([starts(%w[one])])
    expect(result['coverage']['complete']).to be(true)
    expect(result['summary']['unknown']).to eq(1)
  end
end
