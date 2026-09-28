RSpec.describe SearchAnalytics::OutcomeRates, :truncation do
  let(:now) { Time.utc(2026, 9, 16, 12) }
  let(:date) { Date.new(2026, 9, 14) }
  let(:region) { 'eu-west-2' }
  let(:db) { SearchAnalyticsQueryResult.db }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('Outcome reads must not collect logs')
  end

  after do
    next unless SearchAnalytics::OutcomeRatesViews.ready? || relations_present?

    SearchAnalyticsQueryResult.where(name: SearchAnalytics::OutcomeRatesViews::SOURCE_NAMES).delete
    SearchAnalytics::OutcomeRatesViews.refresh!(concurrently: false, force: true) if SearchAnalytics::OutcomeRatesViews.ready? || relations_present?
  end

  def relations_present?
    SearchAnalytics::OutcomeRatesViews::MATVIEWS.all? do |name|
      db.fetch('SELECT 1 FROM pg_class WHERE relname = ? AND relkind = ?', name, 'm').any?
    end
  end

  def definitions(service: 'uk')
    previous = TradeTariffBackend.service
    allow(TradeTariffBackend).to receive(:service).and_return(service)
    SearchAnalytics::DailyQuery.new(reporting_date: date, region:, log_group_name: 'example-logs', now:).fingerprints
  ensure
    allow(TradeTariffBackend).to receive(:service).and_return(previous)
  end

  def key(value) = Digest::SHA256.hexdigest(value)

  def store(day, name, rows, service: 'uk', fingerprint: definitions(service:).fetch(name))
    SearchAnalyticsQueryResult.create(
      service:, reporting_date: day, name:, fingerprint:,
      rows: Sequel.pg_jsonb(rows), collected_at: now
    )
  end

  def frontend(journey, outcome, at, event: nil, question: nil, destination: '', response_source: nil)
    {
      'journey_key' => key(journey),
      'event_key' => event && key(event),
      'question_key' => question && key(question),
      'outcome' => outcome,
      'destination' => destination,
      'response_source' => response_source,
      'observed_at' => at,
      'event_count' => '1',
    }.compact
  end

  def classic(journey, result_count, at, **extra)
    { 'journey_key' => key(journey), 'result_count' => result_count.to_s, 'observed_at' => at, 'event_count' => '1' }.merge(extra.stringify_keys)
  end

  def refresh!
    SearchAnalytics::OutcomeRatesViews.refresh!(concurrently: false, force: true)
  end

  def rates(dates: [date], view: 'all', service: 'uk')
    described_class.call(service:, dates:, view:, definitions: definitions(service:))
  end

  it 'keeps the journey dashboard ready when outcome views are not populated' do
    SearchAnalytics::MaterializedViews.refresh!(concurrently: false, force: true) unless SearchAnalytics::MaterializedViews.ready?
    SearchAnalytics::OutcomeRatesViews::MATVIEWS.each do |name|
      db.run("REFRESH MATERIALIZED VIEW #{name} WITH NO DATA")
    end

    expect(SearchAnalytics::MaterializedViews.ready?).to be(true)
    expect(SearchAnalytics::OutcomeRatesViews.ready?).to be(false)
    expect(rates.dig('outcome_rates', 'classic')).to include('available' => false, 'reason' => 'not_bootstrapped', 'percentages' => nil)
  end

  it 'classifies guided journeys from visibility events and keeps a delayed duplicate behind the later outcome' do
    store(date, 'frontend_events', [
      frontend('one', 'initial_submitted', '2026-09-14T09:00:00Z', event: 'start'),
      frontend('one', 'page_visible', '2026-09-14T10:00:00Z', event: 'results', destination: 'results'),
      frontend('one', 'page_visible', '2026-09-14T11:00:00Z', event: 'guidance', destination: 'blocking_guidance'),
      frontend('one', 'page_visible', '2026-09-14T12:00:00Z', event: 'results', destination: 'results'),
      frontend('two', 'initial_submitted', '2026-09-14T09:00:00Z', event: 'start-two'),
      frontend('two', 'results', '2026-09-14T10:00:00Z', event: 'rendered'),
      frontend('three', 'initial_submitted', '2026-09-14T09:00:00Z', event: 'start-three'),
      frontend('three', 'page_visible', '2026-09-14T10:00:00Z', event: 'error', destination: 'input_error'),
      frontend('three', 'page_visible', '2026-09-14T10:30:00Z', event: 'backend', destination: 'backend_error'),
    ])
    store(date, 'classic_outcomes', [])
    refresh!

    guided = rates.dig('outcome_rates', 'guided')
    expect(guided).to include('available' => true, 'denominator' => 3)
    expect(guided['counts']).to include('blocking_guidance' => 1, 'abandonment' => 1, 'error' => 1, 'results' => 0)
    expect(guided['percentages'].values.sum).to eq(100.0)
    expect(guided['coverage']).to include('complete' => true, 'fresh_days' => 1)
  end

  it 'uses the latest same-day question response and ignores browser submissions' do
    store(date, 'frontend_events', [
      frontend('one', 'page_visible', '2026-09-14T10:00:00Z', event: 'shown', question: 'material', destination: 'question'),
      frontend('one', 'answer_submitted', '2026-09-14T10:05:00Z', event: 'browser', question: 'material', response_source: 'browser_selected'),
      frontend('one', 'answer_accepted', '2026-09-14T10:06:00Z', event: 'accepted', question: 'material', response_source: 'server_accepted'),
      frontend('one', 'answer_accepted', '2026-09-14T10:07:00Z', event: 'accepted', question: 'material', response_source: 'server_accepted'),
      frontend('one', 'dont_know', '2026-09-14T10:08:00Z', event: 'unknown', question: 'material'),
      frontend('one', 'page_visible', '2026-09-14T11:00:00Z', event: 'other-shown', question: 'use', destination: 'question'),
      frontend('two', 'answer_accepted', '2026-09-14T11:00:00Z', event: 'direct', question: 'direct', response_source: 'server_accepted'),
    ])
    store(date, 'classic_outcomes', [])
    refresh!

    questions = rates['question_outcomes']
    expect(questions['counts']).to eq('server_accepted' => 1, 'dont_know' => 1, 'unanswered' => 1)
    expect(questions['percentages'].values.sum).to eq(100.0)
    expect(questions['percentages'].keys).to eq(described_class::QUESTION_OUTCOMES)
  end

  it 'does not join a terminal event across the UTC day boundary' do
    store(date, 'frontend_events', [frontend('one', 'initial_submitted', '2026-09-14T23:59:00Z', event: 'start')])
    store(date + 1, 'frontend_events', [frontend('one', 'page_visible', '2026-09-15T00:01:00Z', event: 'results', destination: 'results')])
    store(date, 'classic_outcomes', [])
    store(date + 1, 'classic_outcomes', [])
    refresh!

    guided = rates(dates: [date, date + 1]).dig('outcome_rates', 'guided')
    expect(guided['counts']).to include('abandonment' => 1, 'results' => 0)
    expect(guided['denominator']).to eq(1)
    expect(guided['coverage']).to include('complete' => true, 'fresh_days' => 2)
  end

  it 'keeps a missing day out of the abandonment count and excludes a stale definition' do
    store(date, 'frontend_events', [frontend('one', 'initial_submitted', '2026-09-14T09:00:00Z', event: 'start')])
    store(date, 'classic_outcomes', [classic('search', 0, '2026-09-14T09:00:00Z', commodity_result_count: '4')])
    refresh!
    SearchAnalyticsQueryResult.where(reporting_date: date, name: 'frontend_events').update(fingerprint: 'obsolete')

    payload = rates(dates: [date, date + 1])
    expect(payload.dig('outcome_rates', 'guided', 'coverage')).to include(
      'missing_dates' => [(date + 1).iso8601], 'stale_dates' => [date.iso8601], 'fresh_days' => 0, 'complete' => false,
    )
    expect(payload.dig('outcome_rates', 'guided')).to include('available' => false, 'reason' => 'no_fresh_days', 'denominator' => nil, 'percentages' => nil, 'percentage_status' => 'unavailable')
    expect(payload.dig('outcome_rates', 'classic', 'counts')).to eq('results' => 0, 'no_results' => 1)
    expect(payload.dig('outcome_rates', 'classic', 'percentages')).to eq('results' => 0.0, 'no_results' => 100.0)
  end

  it 'classifies classic searches by total result count and the latest completion' do
    store(date, 'classic_outcomes', [
      classic('empty', 0, '2026-09-14T09:00:00Z', commodity_result_count: '5'),
      classic('heading', 2, '2026-09-14T09:00:00Z', commodity_result_count: '0'),
      classic('changed', 0, '2026-09-14T09:00:00Z'),
      classic('changed', 3, '2026-09-14T10:00:00Z'),
      classic('invalid', 'nope', '2026-09-14T09:00:00Z'),
    ])
    store(date, 'classic_outcomes', [classic('other-service', 0, '2026-09-14T09:00:00Z')], service: 'xi')
    store(date, 'frontend_events', [])
    refresh!

    classic_rates = rates.dig('outcome_rates', 'classic')
    expect(classic_rates['counts']).to eq('results' => 2, 'no_results' => 1)
    expect(classic_rates['percentages'].values.sum).to eq(100.0)
    expect(rates(service: 'xi').dig('outcome_rates', 'classic', 'counts')).to eq('results' => 0, 'no_results' => 1)
    expect(rates(view: 'internal').dig('outcome_rates', 'classic')).to include('supported' => false, 'percentage_status' => 'unsupported')
    expect(rates(view: 'classic')['question_outcomes']).to include('supported' => false)
    expect(rates(view: 'classic').to_json).not_to include(key('empty'))
  end

  it 'makes a collected zero denominator unavailable instead of zero percent' do
    store(date, 'classic_outcomes', [])
    store(date, 'frontend_events', [])
    refresh!

    expect(rates.dig('outcome_rates', 'classic')).to include('available' => true, 'denominator' => 0, 'percentages' => nil, 'percentage_status' => 'unavailable')
    expect(rates.dig('outcome_rates', 'guided', 'counts').values).to all(eq(0))
  end
end
