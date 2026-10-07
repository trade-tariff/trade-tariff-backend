RSpec.describe SearchAnalytics::ActionBreakdown do
  let(:dates) { [Date.new(2026, 9, 13), Date.new(2026, 9, 14)] }
  let(:period) { SearchAnalytics::Period.for(period: '7d', view: 'all') }
  let(:definitions) { SearchAnalytics::DailyQuery.new(reporting_date: dates.last, region: 'eu-west-2').fingerprints }
  let(:navigation_keys) { journey_keys('navigation', 3000) }
  let(:search_keys) { journey_keys('search', 3000) }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    dates.each do |date|
      store('search_journeys', date, [
        { '@timestamp' => "#{date.iso8601}T08:00:00Z", 'request_source' => 'frontend', 'search_type' => 'classic', 'journey_keys' => navigation_keys + search_keys },
      ])
      store('search_actions', date, [action(navigation_keys, 'navigation'), action(search_keys, 'search')])
    end
  end

  def store(name, date, rows)
    SearchAnalyticsQueryResult.create(service: 'uk', reporting_date: date, name:, fingerprint: definitions.fetch(name), collected_at: Time.current, rows: Sequel.pg_jsonb(rows))
  end

  def action(keys, search_action)
    { 'search_type' => 'classic', 'request_source' => 'frontend', 'search_action' => search_action, 'journey_keys' => keys }
  end

  delegate :db, to: :SearchAnalyticsQueryResult

  def journey_keys(prefix, count) = Array.new(count) { |index| Digest::SHA256.hexdigest("#{prefix}-#{index}") }

  def payload
    {
      'availability' => { 'journey_metrics' => true },
      'summary' => { 'searches' => 6000 },
      'trends' => { 'volume' => dates.map { |date| { 'bucket' => "#{date.iso8601}T00:00:00Z", 'all' => 6000 } } },
    }
  end

  # Each stored row holds thousands of journey keys. If the grouping step
  # carries the whole JSONB row with every key, a 7-day read spills gigabytes
  # to disk and takes about 30 seconds in production.
  def read_with_small_memory(materialized:)
    db.transaction do
      db.run("SET LOCAL work_mem = '64kB'")
      db.run("SET LOCAL temp_file_limit = '8MB'")
      described_class.call(service: 'uk', dates:, period:, definitions:, payload:, materialized:)
    end
  end

  shared_examples 'a bounded action count' do |materialized:|
    it 'counts actions without large temporary files' do
      result = read_with_small_memory(materialized:)

      expect(result['summary']).to eq('total' => 6000, 'navigation' => 3000, 'search' => 3000, 'unclassified' => 0)
      expect(result['trend']).to all(include('total' => 6000, 'navigation' => 3000, 'search' => 3000))
    end
  end

  context 'with stored journey starts' do
    it_behaves_like 'a bounded action count', materialized: false
  end

  context 'with materialized journey starts' do
    before { SearchAnalytics::DailyJourney.refresh!(concurrently: false) }

    it_behaves_like 'a bounded action count', materialized: true
  end
end
