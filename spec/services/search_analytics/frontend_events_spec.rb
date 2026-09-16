RSpec.describe SearchAnalytics::FrontendEvents do
  let(:date) { Date.new(2026, 9, 14) }
  let(:record_class) { Data.define(:reporting_date, :rows, :collected_at) }

  def row(key, outcome, **attributes)
    { 'journey_key' => key, 'outcome' => outcome, 'event_count' => '1', 'reported_questions' => nil, 'navigation_observations' => '0', 'navigation_total_ms' => '0' }.merge(attributes.stringify_keys)
  end

  def record(rows, day: date)
    record_class.new(reporting_date: day, rows:, collected_at: Time.utc(2026, 9, 16))
  end

  def aggregate(records, dates: [date], supported: true)
    described_class.call(records:, dates:, supported:)
  end

  it 'keeps rendered and browser-visible event counts separate and deduplicates journey IDs' do
    rows = [row('one', 'results', event_count: '2'), row('one', 'page_visible', destination: 'results'), row('two', 'results')]
    result = aggregate([record(rows)])
    expect(result['observed_journeys']).to eq(2)
    expect(result['outcomes'].find { |item| item['outcome'] == 'results' }).to include('rendered_events' => 3, 'visible_events' => 1, 'journeys' => 2)
  end

  it 'weights navigation means by timed observations, including valid zero durations' do
    rows = [row('one', 'page_visible', destination: 'results', event_count: '2', navigation_total_ms: '0', navigation_observations: '2'), row('two', 'page_visible', destination: 'results', navigation_total_ms: '9000', navigation_observations: '1')]
    outcome = aggregate([record(rows)])['outcomes'].find { |item| item['outcome'] == 'results' }
    expect(outcome).to include('timed_visible_events' => 3, 'average_navigation_ms' => 3000.0)
  end

  it 'does not invent a timing for an outcome without observations' do
    outcome = aggregate([record([row('one', 'results')])])['outcomes'].find { |item| item['outcome'] == 'results' }
    expect(outcome).to include('timed_visible_events' => 0, 'average_navigation_ms' => nil)
  end

  it 'counts recorded actions rather than presenting them as unique clicks or answers' do
    result = aggregate([record([row('one', 'result_selected', event_count: '3'), row('one', 'dont_know')])])
    expect(result['actions']).to eq('result_selected' => 3, 'dont_know' => 1)
  end

  it 'uses the maximum reported question count per journey across dates and keeps unknown distinct from zero' do
    first = record([row('one', 'question', reported_questions: '1'), row('zero', 'results', reported_questions: '0')])
    second = record([row('one', 'results', reported_questions: '3'), row('unknown', 'result_selected')], day: date + 1)
    result = aggregate([first, second], dates: [date, date + 1])
    expect(result['observed_journeys']).to eq(3)
    expect(result['question_counts']).to eq([
      { 'questions' => nil, 'journeys' => 1 }, { 'questions' => 0, 'journeys' => 1 }, { 'questions' => 3, 'journeys' => 1 }
    ])
  end

  it 'retains overflow question counts and treats SQL nulls as unknown' do
    result = aggregate([record([row('one', 'question', reported_questions: '12'), row('two', 'results', reported_questions: 'null')])])
    expect(result['question_counts']).to include({ 'questions' => 12, 'journeys' => 1 }, { 'questions' => nil, 'journeys' => 1 })
  end

  it 'reports partial coverage rather than filling a missing day with zero' do
    result = aggregate([record([])], dates: [date, date + 1])
    expect(result['available']).to be(true)
    expect(result['coverage']).to include('collected_days' => 1, 'expected_days' => 2, 'missing_dates' => [(date + 1).iso8601], 'complete' => false)
  end

  it 'distinguishes a successful empty query from an unavailable query' do
    expect(aggregate([record([])])).to include('available' => true, 'observed_journeys' => 0)
    expect(aggregate([])).to include('available' => false, 'generated_at' => nil)
  end

  it 'does not expose guided UK data for an unsupported service or view' do
    result = aggregate([record([row('private-key', 'results')])], supported: false)
    expect(result).to include('available' => false, 'observed_journeys' => 0)
    expect(result['coverage']).to include('supported' => false, 'complete' => false)
    expect(result.to_json).not_to include('private-key')
  end
end
