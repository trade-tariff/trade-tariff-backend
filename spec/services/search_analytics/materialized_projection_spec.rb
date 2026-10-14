# frozen_string_literal: true

RSpec.describe SearchAnalytics::MaterializedProjection do
  let(:service) { 'uk' }
  let(:first_date) { Date.new(2099, 3, 14) }
  let(:second_date) { Date.new(2099, 3, 15) }
  let(:dates) { [first_date, second_date] }
  let(:db) { SearchAnalytics::RepeatedJourney.db }

  # Materialized views are read-only. Session tables with the same names let the
  # projection SQL run against controlled hour masks and flag bits.
  before { shadow_views }

  describe '#summary' do
    before { insert_repeated_journeys }

    it 'counts seen views and flag bits' do
      projection = build_projection

      expect(projection.summary('classic')).to eq(counts(4, 'classic', completed: 3, nonterminal: 1, selected: 1))
      expect(projection.summary('internal')).to eq(counts(3, 'internal', completed: 1, failed: 1, unknown: 1, zero_result: 1))
      expect(projection.summary('all')).to eq(counts(7, 'all', completed: 3, failed: 1, nonterminal: 1, unknown: 2, selected: 1, zero_result: 1))
    end

    it 'returns zeros for an empty window' do
      projection = build_projection(dates: [Date.new(2026, 1, 1), Date.new(2026, 1, 2)])

      expect(projection.summary('all')).to eq(counts(0))
    end
  end

  describe '#trend' do
    before { insert_repeated_journeys }

    it 'omits days without positive hours' do
      expect(build_projection.trend).to eq([
        trend_row(first_date, all: 5, classic: 3, internal: 1),
        trend_row(second_date, all: 5, classic: 2, internal: 2),
      ])
    end
  end

  describe '#outcomes' do
    before { insert_repeated_journeys }

    it 'returns flag series for covered days' do
      coverage = { 'complete' => true, 'collected_days' => 2 }
      buckets = [bucket(first_date), bucket(second_date), '2026-09-20T00:00:00Z']
      result = build_projection.outcomes(view: 'classic', buckets:, coverage:)

      expect(result['coverage']).to eq(coverage)
      expect(result['summary']).to eq(series(completed: 3, nonterminal: 1, selected: 1))
      expect(result['trend']).to eq([
        series(first_date, completed: 3, selected: 1),
        series(second_date, completed: 1, nonterminal: 1),
        series(Date.new(2026, 9, 20)),
      ])
    end

    it 'classifies unknown flag bits ahead of nonterminal bits' do
      coverage = { 'complete' => true, 'collected_days' => 2 }
      result = build_projection.outcomes(view: 'internal', buckets: [bucket(first_date), bucket(second_date)], coverage:)

      expect(result['summary']).to eq(series(completed: 1, failed: 1, unknown: 1, zero_result: 1))
      expect(result['trend']).to eq([
        series(first_date, unknown: 1),
        series(second_date, completed: 1, failed: 1, zero_result: 1),
      ])
    end

    it 'omits the summary when incomplete' do
      coverage = { 'complete' => false, 'collected_days' => 1 }
      result = build_projection.outcomes(view: 'classic', buckets: [bucket(first_date)], coverage:)

      expect(result['summary']).to be_nil
      expect(result['trend']).to eq([series(first_date, completed: 3, selected: 1)])
    end

    it 'omits the trend without collected days' do
      coverage = { 'complete' => true, 'collected_days' => 0 }
      result = build_projection.outcomes(view: 'classic', buckets: [bucket(first_date)], coverage:)

      expect(result['summary']).to eq(series(completed: 3, nonterminal: 1, selected: 1))
      expect(result['trend']).to eq([])
    end
  end

  describe '#cost_keys' do
    before do
      insert_repeated_journeys
      insert_cost_rows
    end

    it 'keeps keys with positive view hours' do
      expect(cost_projection(view: 'classic').cost_keys).to eq(keyed(%w[split classic_selected classic_plain classic_nonterminal]))
      expect(cost_projection(view: 'internal').cost_keys).to eq(keyed(%w[split internal_zero internal_unknown]))
      expect(cost_projection(view: 'all').cost_keys).to eq(keyed(%w[split classic_selected classic_plain classic_nonterminal internal_zero internal_unknown all_only]))
    end

    it 'returns nothing without cost rows' do
      expect(build_projection(costs: []).cost_keys).to eq({})
    end
  end

  describe '#terms' do
    before { insert_terms }

    it 'sums numeric totals for the view' do
      expect(terms_projection(view: 'classic').terms).to eq([
        term('123456', 'item_ids', 5),
        term('111', 'item_ids', 1),
        term('zebra', 'search_terms', 10),
        term('apple', 'search_terms', 2),
        term('mango', 'search_terms', 2),
        term('bad', 'search_terms', 0),
      ])
      expect(terms_projection(view: 'internal').terms).to eq([
        term('999', 'item_ids', 7),
        term('apple', 'search_terms', 100),
      ])
      expect(terms_projection(view: 'all').terms).to eq([
        term('999', 'item_ids', 7),
        term('123456', 'item_ids', 5),
        term('111', 'item_ids', 1),
        term('apple', 'search_terms', 102),
        term('zebra', 'search_terms', 10),
        term('mango', 'search_terms', 2),
        term('bad', 'search_terms', 0),
      ])
    end

    it 'keeps the top rank in each term type' do
      stub_const('SearchAnalytics::CloudwatchSnapshotQuery::IMPROVEMENT_TERM_LIMIT', 1)

      expect(terms_projection(view: 'classic').terms).to eq([
        term('123456', 'item_ids', 5),
        term('zebra', 'search_terms', 10),
      ])
    end
  end

  def shadow_views
    %w[search_analytics_repeated_journeys search_analytics_daily_journeys search_analytics_journey_rollup_totals].each do |name|
      db.run("DROP TABLE IF EXISTS pg_temp.#{name}")
      db.run("CREATE TEMP TABLE #{name} (LIKE #{name} INCLUDING ALL)")
    end
  end

  def insert_repeated_journeys
    # Day values are all hours, classic hours, internal hours, terminal, flags.
    # Flag bits: 1 selected, 2 zero_result, 4 nonterminal, 8 unknown.
    [
      ['split', [1, 1, 0, 1, 0], [1, 0, 1, 1, 0]],
      ['classic_selected', [1, 1, 0, 1, 1], [0, 0, 0, 1, 0]],
      ['classic_plain', [1, 1, 0, 1, 0], [1, 1, 0, 1, 0]],
      ['classic_nonterminal', [0, 0, 0, nil, 0], [1, 1, 0, nil, 4]],
      ['internal_zero', [0, 0, 0, 2, 0], [1, 0, 1, 2, 2]],
      ['internal_unknown', [1, 0, 1, nil, 12], [0, 0, 0, nil, 0]],
      ['all_only', [1, 0, 0, nil, 0], [1, 0, 0, nil, 0]],
      ['silent', [0, 0, 0, 1, 1], [0, 0, 0, 1, 1]],
    ].each do |name, first_day, second_day|
      insert_journey(name, first_date, *first_day)
      insert_journey(name, second_date, *second_day)
    end
    insert_journey('outside', Date.new(2099, 3, 13), 1, 1, 0, 1, 1)
    insert_journey('xi_only', first_date, 1, 1, 1, 1, 1, service: 'xi')
    insert_journey('xi_only', second_date, 1, 1, 1, 1, 1, service: 'xi')
  end

  def insert_cost_rows
    insert_journey('stale', first_date, 1, 1, 0, 1, 0, tables: [:search_analytics_daily_journeys])
    rows = %w[split classic_selected classic_plain classic_nonterminal internal_zero internal_unknown all_only silent].map do |name|
      { 'journey_key' => hex(name) }
    end
    rows << { 'event_kind' => 'missing-key' }
    dates.each { |date| store_result('ai_cost_trend', rows, fingerprint: 'cost-v1', date:) }
    store_result('ai_cost_trend', [{ 'journey_key' => hex('stale') }], fingerprint: 'stale', date: stale_date)
  end

  def insert_terms
    store_result('search_term_improvements', [
      { 'query' => 'zebra', 'search_type' => 'classic', 'zero_results' => '10' },
      { 'query' => 'apple', 'search_type' => 'classic', 'zero_results' => '2.9' },
      { 'query' => 'apple', 'search_type' => 'interactive', 'zero_results' => '100' },
      { 'query' => 'mango', 'search_type' => 'classic', 'zero_results' => '2' },
      { 'query' => 'bad', 'search_type' => 'classic', 'zero_results' => 'nope' },
      { 'query' => ' ', 'search_type' => 'classic', 'zero_results' => '99' },
      { 'query' => '', 'search_type' => 'classic', 'zero_results' => '99' },
      { 'search_type' => 'classic', 'zero_results' => '99' },
    ], fingerprint: 'terms-v1')
    store_result('item_id_improvements', [
      { 'query' => '123456', 'search_type' => 'classic', 'zero_results' => '5' },
      { 'query' => '111', 'search_type' => 'classic', 'zero_results' => '1' },
      { 'query' => '999', 'search_type' => 'internal', 'zero_results' => '7' },
    ], fingerprint: 'items-v1')
    store_result('search_term_improvements', [
      { 'query' => 'zebra', 'search_type' => 'classic', 'zero_results' => '1000' },
    ], fingerprint: 'stale', date: stale_date)
  end

  def insert_journey(name, date, all_hours, classic_hours, internal_hours, terminal, flags, service: 'uk', tables: %i[search_analytics_repeated_journeys search_analytics_daily_journeys])
    tables.each do |table|
      db[table].insert(
        service:,
        reporting_date: date,
        journey_key: Sequel.function(:decode, hex(name), 'hex'),
        all_hours:,
        classic_hours:,
        internal_hours:,
        terminal:,
        flags:,
      )
    end
  end

  def store_result(name, rows, fingerprint:, date: first_date, service: 'uk')
    SearchAnalyticsQueryResult.create(
      service:,
      reporting_date: date,
      name:,
      fingerprint:,
      rows: Sequel.pg_jsonb(rows),
      collected_at: Time.utc(2026, 9, 16),
    )
  end

  def build_projection(view: 'all', dates: self.dates, costs: [{ 'present' => true }], term_dates: dates, cost_dates: dates, **overrides)
    described_class.new(
      service:,
      dates:,
      period: SearchAnalytics::Period.new(key: 'custom', view:, duration: 2.days, bucket_size: 'day'),
      costs:,
      cost_fingerprint: 'cost-v1',
      term_dates:,
      cost_dates:,
      term_fingerprints: {
        'item_id_improvements' => 'items-v1',
        'search_term_improvements' => 'terms-v1',
      },
      **overrides,
    )
  end

  def terms_projection(view:)
    build_projection(view:, term_dates: dates + [stale_date])
  end

  def cost_projection(view:)
    build_projection(view:, cost_dates: dates + [stale_date])
  end

  def stale_date = Date.new(2099, 3, 16)

  def counts(journeys, view = nil, **flags)
    row = series(**flags).merge('journeys' => journeys)
    return row unless view

    row.merge('view' => view, 'bucket' => nil)
  end

  def series(date = nil, **flags)
    row = SearchAnalytics::JourneyOutcomes::SERIES.index_with { 0 }.merge(flags.transform_keys(&:to_s))
    return row unless date

    { 'bucket' => bucket(date), **row }
  end

  def trend_row(date, all:, classic:, internal:)
    { 'bucket' => bucket(date), 'all' => all, 'classic' => classic, 'internal' => internal }
  end

  def term(query, term_type, zero_results)
    { 'query' => query, 'term_type' => term_type, 'zero_results' => zero_results }
  end

  def keyed(names)
    names.index_with { true }.transform_keys { |name| hex(name) }
  end

  def bucket(date) = "#{date.iso8601}T00:00:00Z"

  def hex(name) = Digest::SHA256.hexdigest(name)
end
