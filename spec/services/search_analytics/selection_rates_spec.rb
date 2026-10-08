RSpec.describe SearchAnalytics::SelectionRates do
  let(:dates) { [Date.new(2026, 9, 13), Date.new(2026, 9, 14)] }
  let(:definitions) { SearchAnalytics::DailyQuery.new(reporting_date: dates.last, region: 'eu-west-2').fingerprints }

  def store(name, date, rows, fingerprint: definitions.fetch(name), service: 'uk')
    SearchAnalyticsQueryResult.create(service:, reporting_date: date, name:, fingerprint:, collected_at: Time.current, rows: Sequel.pg_jsonb(rows))
  end

  def result(type, *ids)
    { 'search_type' => type, 'journey_keys' => ids.map { |id| Digest::SHA256.hexdigest(id) } }
  end

  def selected(*ids) = result(nil, *ids).except('search_type')
  def read = described_class.call(service: 'uk', dates:, definitions:)

  it 'deduplicates across days and joins later page visits without counting clicks or completions twice' do
    store('selection_results', dates.first, [result('classic', 'a', 'b'), result('interactive', 'c')])
    store('selection_results', dates.last, [result('classic', 'a'), result('internal', 'c', 'd')])
    store('selection_pages', dates.first, [selected('a', 'a', 'not-a-result')])
    store('selection_pages', dates.last, [selected('a', 'b', 'c', 'c')])
    expect(read.fetch(:views)).to eq(
      'all' => { 'result_journeys' => 4, 'selected_result_journeys' => 3, 'selection_rate' => 0.75 },
      'classic' => { 'result_journeys' => 2, 'selected_result_journeys' => 2, 'selection_rate' => 1.0 },
      'internal' => { 'result_journeys' => 2, 'selected_result_journeys' => 1, 'selection_rate' => 0.5 },
    )
    expect(read.dig(:coverage, 'complete')).to be(true)
  end

  it 'counts a journey observed in both types only once in All' do
    dates.each do |date|
      store('selection_results', date, [result('classic', 'same'), result('interactive', 'same')])
      store('selection_pages', date, [selected('same')])
    end
    expect(read.fetch(:views).values).to all(include('result_journeys' => 1, 'selected_result_journeys' => 1))
  end

  it 'does not report zero when a later page collection is missing' do
    store('selection_results', dates.first, [result('classic', 'a')])
    store('selection_pages', dates.first, [])
    store('selection_results', dates.last, [result('classic', 'a')])
    store('selection_pages', dates.last, [selected('a')], fingerprint: 'stale')
    store('selection_pages', dates.last, [selected('a')], service: 'xi')
    expect(read.dig(:views, 'classic')).to include('result_journeys' => nil, 'selected_result_journeys' => nil, 'selection_rate' => nil)
    expect(read.fetch(:coverage)).to include('complete' => false, 'collected_days' => 1, 'missing_dates' => [dates.last.iso8601])
  end

  it 'does not represent missing collection as zero selections' do
    store('selection_results', dates.first, [result('classic', 'a')])
    expect(read.dig(:views, 'classic')).to include('result_journeys' => nil, 'selected_result_journeys' => nil, 'selection_rate' => nil)
  end

  it 'distinguishes a collected zero selection rate from an empty denominator' do
    dates.each do |date|
      store('selection_results', date, [result('classic', 'a')])
      store('selection_pages', date, [])
    end
    expect(read.dig(:views, 'classic')).to include('result_journeys' => 1, 'selected_result_journeys' => 0, 'selection_rate' => 0.0)
    expect(read.dig(:views, 'internal')).to include('result_journeys' => 0, 'selected_result_journeys' => 0, 'selection_rate' => nil)
  end

  it 'ignores page visits without an eligible result journey' do
    dates.each do |date|
      store('selection_results', date, [])
      store('selection_pages', date, [selected('navigation', 'questions', 'empty')])
    end
    expect(read.dig(:views, 'all')).to include('result_journeys' => 0, 'selected_result_journeys' => 0, 'selection_rate' => nil)
  end

  it 'serves standalone selection history without writing or collecting other query groups' do
    dates.each do |date|
      store('selection_results', date, [result('classic', 'a', 'b')])
      store('selection_pages', date, [selected('a')])
    end
    stored = SearchAnalyticsQueryResult.order(:id).all.map(&:values)
    expect(Aws::CloudWatchLogs::Client).not_to receive(:new)
    range = SearchAnalytics::DateRange.parse(from: dates.first.iso8601, to: dates.last.iso8601)
    payload = SearchAnalytics::DailyResults.call(period: SearchAnalytics::Period.for_range(date_range: range, view: 'classic'), date_range: range, region: 'eu-west-2').payload
    expect(payload['summary']).to include('searches' => nil, 'selection_rate' => 0.5, 'result_journeys' => 2, 'selected_result_journeys' => 1)
    expect(payload.dig('availability', 'selection_rate_coverage')).to include('complete' => true)
    expect(payload.dig('comparisons', 'classic')).to include('selection_rate' => 0.5)
    expect(payload.dig('request_sources', 'frontend')).to include('selection_rate' => 0.5)
    expect(payload.dig('request_sources', 'backend_only')).to include('selection_rate' => nil)
    expect(SearchAnalyticsQueryResult.order(:id).all.map(&:values)).to eq(stored)
  end

  # Each stored row holds thousands of journey keys. If the grouping step
  # carries the whole JSONB row with every key, a 7-day read spills gigabytes
  # to disk and takes about 30 seconds in production.
  it 'counts selections without large temporary files' do
    classic = Array.new(3000) { |index| "classic-#{index}" }
    internal = Array.new(3000) { |index| "internal-#{index}" }
    dates.each do |date|
      store('selection_results', date, [result('classic', *classic), result('internal', *internal)])
      store('selection_pages', date, [selected(*classic.first(1000), *internal.first(500))])
    end

    views = SearchAnalyticsQueryResult.db.transaction do
      SearchAnalyticsQueryResult.db.run("SET LOCAL work_mem = '64kB'")
      SearchAnalyticsQueryResult.db.run("SET LOCAL temp_file_limit = '8MB'")
      read.fetch(:views)
    end

    expect(views.transform_values { |view| view.slice('result_journeys', 'selected_result_journeys') }).to eq(
      'all' => { 'result_journeys' => 6000, 'selected_result_journeys' => 1500 },
      'classic' => { 'result_journeys' => 3000, 'selected_result_journeys' => 1000 },
      'internal' => { 'result_journeys' => 3000, 'selected_result_journeys' => 500 },
    )
  end
end
