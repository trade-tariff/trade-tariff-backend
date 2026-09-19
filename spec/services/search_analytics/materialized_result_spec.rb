RSpec.describe SearchAnalytics::MaterializedResult, :truncation do
  let(:first_date) { Date.new(2026, 9, 14) }
  let(:now) { Time.utc(2026, 9, 16) }
  let(:scope) { { region: 'eu-west-2', log_group_name: 'example-logs', now: } }
  let(:service) { 'uk' }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return(service)
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('Reads must not query AWS')
    store_day(first_date)
    store_day(first_date + 1)
  end

  def key(value) = Digest::SHA256.hexdigest(value)

  def store_day(date)
    definitions = SearchAnalytics::DailyQuery.new(reporting_date: date, **scope).fingerprints
    bucket = (date.to_time(:utc) + 8.hours).iso8601
    groups = definitions.keys.index_with { [] }
    groups['search_journeys'] = [
      { '@timestamp' => bucket, 'search_type' => 'classic', 'request_source' => 'frontend', 'journey_keys' => [key("classic-#{date}")] },
      { '@timestamp' => bucket, 'search_type' => 'interactive', 'request_source' => 'frontend', 'journey_keys' => [key('shared'), key("question-#{date}")] },
      { '@timestamp' => bucket, 'search_type' => 'classification', 'request_source' => 'frontend', 'journey_keys' => [key("classification-#{date}")] },
    ]
    groups['volume'] = %w[classic interactive classification].map do |type|
      { '@timestamp' => bucket, 'search_type' => type, 'request_source' => 'frontend', 'event' => 'search_completed', 'searches' => '5', 'zero_results' => '1' }
    end
    groups['journey_outcomes'] = [
      outcome(date, [key("classic-#{date}"), key("classification-#{date}"), key("admin-#{date}")], 'completed', 'selected' => '1', 'total_questions' => '0'),
      outcome(date, [key('shared')], date == first_date ? 'failed' : 'completed', 'zero_result' => '1', 'total_questions' => date == first_date ? '1' : '2'),
      outcome(date, [key("question-#{date}")], 'none', 'questions_seen' => '1', 'total_questions' => '3'),
    ]
    groups['ai_cost_trend'] = [key('shared'), key("admin-#{date}")].map do |id|
      { '@timestamp' => bucket, 'journey_key' => id, 'event_kind' => 'interactive_search_completed', 'model' => 'gpt-5.4', 'total_cost_usd' => '0.012345678', 'priced_calls' => '1', 'unpriced_calls' => '0', 'calls' => '1' }
    end
    groups['search_term_improvements'] = %w[zebra apple äpple].map do |query|
      { 'query' => query, 'search_type' => 'interactive', 'zero_results' => '2' }
    end
    groups['item_id_improvements'] = [{ 'query' => '123456', 'search_type' => 'classic', 'zero_results' => '3' }]
    %w[classic internal].each do |view|
      groups["#{view}_selection_trend"] = [{ '@timestamp' => bucket, 'source' => 'frontend', 'selected' => '1', 'selectable' => '2' }]
    end
    groups.each do |name, rows|
      SearchAnalyticsQueryResult.create(service:, reporting_date: date, name:, fingerprint: definitions.fetch(name), collected_at: now, rows: Sequel.pg_jsonb(rows))
    end
  end

  def outcome(date, ids, state, flags = {})
    { 'journey_keys' => ids,
      'terminal_state' => state,
      'window_end' => (date.to_time(:utc) + 12.hours).iso8601,
      'questions_seen' => '0',
      'unknown_seen' => '0',
      'selected' => '0',
      'zero_result' => '0' }.merge(flags)
  end

  def rebuild
    SearchAnalytics::MaterializedViews.refresh!(force: true)
  end

  def arguments(view: 'all', from: first_date, to: first_date + 1)
    scope.merge(period: SearchAnalytics::Period.for(period: 'custom', view:), date_range: SearchAnalytics::DateRange.parse(from: from.iso8601, to: to.iso8601, now:))
  end

  def expect_parity(**options)
    args = arguments(**options)
    expected = SearchAnalytics::DailyResults.legacy_call(**args)
    projected = described_class.call(**args)
    expect(projected.available).to be(true)
    expect(projected.value).to eq(expected)
  end

  context 'with populated materialized views' do
    before { rebuild }

    %w[all classic internal].each do |view|
      it "preserves all #{view} fields over multiple days, including recovered failures and cost attribution" do
        expect_parity(view:)
      end

      it "preserves #{view} hourly buckets for a single day" do
        expect_parity(view:, from: first_date + 1)
      end
    end

    it 'preserves partial range coverage without counting missing days as zero' do
      expect_parity(from: first_date - 2)
    end

    it 'joins costs across midnight only when the frontend start is in the selected range' do
      SearchAnalyticsQueryResult.where(reporting_date: first_date + 1, name: 'search_journeys').update(rows: Sequel.pg_jsonb([]))
      rebuild
      args = arguments
      expect(described_class.call(**args).value.payload.dig('ai_costs', 'summary', 'total_cost_usd')).to eq(
        SearchAnalytics::DailyResults.legacy_call(**args).payload.dig('ai_costs', 'summary', 'total_cost_usd'),
      )
      single = arguments(view: 'internal', from: first_date + 1, to: first_date + 1)
      expect(described_class.call(**single).value.payload.dig('ai_costs', 'summary', 'total_cost_usd')).to eq(
        SearchAnalytics::DailyResults.legacy_call(**single).payload.dig('ai_costs', 'summary', 'total_cost_usd'),
      )
    end

    it 'ignores changes outside the selected dates' do
      SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'search_journeys').update(collected_at: now + 1)
      expect_parity(from: first_date + 1)
    end

    it 'keeps partial-day exclusion correct after a required group is deleted' do
      SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'volume').delete
      expect_parity
    end

    it 'preserves terminal ordering within the same second' do
      row = SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'journey_outcomes').first
      rows = [
        outcome(first_date, [key('shared')], 'failed').merge('window_end' => '2026-09-14T12:00:00.100000Z'),
        outcome(first_date, [key('shared')], 'completed').merge('window_end' => '2026-09-14T12:00:00.200000Z'),
      ]
      row.update(rows: Sequel.pg_jsonb(rows), collected_at: now + 1)
      rebuild
      expect_parity(to: first_date)
    end

    it 'preserves conflicts for different terminal states at the same instant' do
      row = SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'journey_outcomes').first
      rows = %w[completed failed].map { |state| outcome(first_date, [key('shared')], state) }
      row.update(rows: Sequel.pg_jsonb(rows), collected_at: now + 1)
      rebuild
      expect_parity(to: first_date)
    end

    it 'sums daily term counts across search types the same way as the existing reader' do
      SearchAnalyticsQueryResult.where(name: 'search_term_improvements').each do |row|
        rows = [
          { 'query' => 'shared-term', 'search_type' => 'classic', 'zero_results' => '10' },
          { 'query' => 'shared-term', 'search_type' => 'interactive', 'zero_results' => '3' },
        ]
        row.update(rows: Sequel.pg_jsonb(rows), collected_at: now + 1)
      end
      expect_parity(view: 'all')
      terms = described_class.call(**arguments(view: 'all')).value.payload.fetch('improvement_terms')
      expect(terms).to include(hash_including('query' => 'shared-term', 'zero_results' => 26))
    end

    it 'ranks complete range totals before applying each term-type limit' do
      rows = Array.new(150) { |index| { 'query' => sprintf('term-%03d', index), 'search_type' => 'classic', 'zero_results' => (index % 5).to_s } }
      rows += [
        { 'query' => 'decimal', 'search_type' => 'classic', 'zero_results' => '2.8' },
        { 'query' => 'unknown-count', 'search_type' => 'classic', 'zero_results' => 'invalid' },
        { 'query' => ' ', 'search_type' => 'classic', 'zero_results' => '9999' },
      ]
      SearchAnalyticsQueryResult.where(name: 'search_term_improvements').update(rows: Sequel.pg_jsonb(rows), collected_at: now + 1)
      expect_parity(view: 'classic')
      terms = described_class.call(**arguments(view: 'classic')).value.payload.fetch('improvement_terms')
      expect(terms.count { |row| row['term_type'] == 'search_terms' }).to eq(100)
    end

    it 'declines the fast path inside an existing caller transaction' do
      SearchAnalyticsQueryResult.db.transaction do
        expect(described_class.call(**arguments).available).to be(false)
        expect(SearchAnalytics::DailyResults.call(**arguments)).to eq(SearchAnalytics::DailyResults.legacy_call(**arguments))
      end
    end

    it 'restores the connection work_mem setting after reading' do
      db = SearchAnalyticsQueryResult.db
      db.synchronize do
        before = db.fetch('SHOW work_mem').first
        described_class.call(**arguments)
        expect(db.fetch('SHOW work_mem').first).to eq(before)
      end
    end

    it 'pins source rows and all four materialized views across an atomic concurrent refresh' do
      expected = SearchAnalytics::DailyResults.legacy_call(**arguments)
      ready = Queue.new
      release = Queue.new
      pause = true
      allow(SearchAnalytics::MaterializedProjection).to receive(:new).and_wrap_original do |method, **args|
        if pause
          pause = false
          ready << true
          release.pop
        end
        method.call(**args)
      end
      reader = Thread.new { SearchAnalytics::DailyResults.call(**arguments) }
      Timeout.timeout(10) { ready.pop }
      row = SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'search_journeys').first
      rows = row.rows.to_a.deep_dup
      rows.first['journey_keys'] << key('concurrent-replacement')
      row.update(rows: Sequel.pg_jsonb(rows), collected_at: now + 1)
      rebuild
      release << true
      expect(Timeout.timeout(10) { reader.value }).to eq(expected)
      expect_parity
    ensure
      release << true if release
      reader&.join(10)
      reader&.kill if reader&.alive?
    end

    it 'does not load identifier or term blobs into Ruby' do
      expect(SearchAnalytics::MaterializedAggregate).to receive(:new).and_wrap_original do |method, **args|
        expect(args.fetch(:results).keys).not_to include('search_journeys', 'journey_outcomes', 'search_term_improvements', 'item_id_improvements')
        method.call(**args)
      end
      expect_parity
    end

    it 'keeps successful coverage when observed events are empty' do
      SearchAnalyticsQueryResult.dataset.delete
      definitions = SearchAnalytics::DailyQuery.new(reporting_date: first_date, **scope).fingerprints
      definitions.each_key do |name|
        SearchAnalyticsQueryResult.create(service:, reporting_date: first_date, name:, fingerprint: definitions.fetch(name), collected_at: now, rows: Sequel.pg_jsonb([]))
      end
      rebuild
      expect_parity(from: first_date, to: first_date)
    end
  end

  context 'with incompatible derived data' do
    before { rebuild }

    it 'falls back after a successful source replacement' do
      previous_count = SearchAnalytics::DailyResults.legacy_call(**arguments).payload.dig('summary', 'searches')
      row = SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'search_journeys').first
      rows = row.rows.to_a.deep_dup
      rows.first['journey_keys'] << key('replacement')
      row.update(rows: Sequel.pg_jsonb(rows), collected_at: now + 1)
      expect(described_class.call(**arguments).available).to be(false)
      current = SearchAnalytics::DailyResults.call(**arguments)
      expect(current).to eq(SearchAnalytics::DailyResults.legacy_call(**arguments))
      expect(current.payload.dig('summary', 'searches')).to eq(previous_count + 1)
      rebuild
      expect_parity
    end

    it 'does not serve old outcomes after deletion' do
      SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'journey_outcomes').delete
      expect(described_class.call(**arguments).available).to be(false)
      expect(SearchAnalytics::DailyResults.call(**arguments).payload.dig('availability', 'journey_outcomes')).to be(false)
      rebuild
      expect_parity
    end

    it 'does not serve a stale outcome fingerprint' do
      SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'journey_outcomes').update(fingerprint: 'obsolete')
      expect(described_class.call(**arguments).available).to be(false)
      rebuild
      expect_parity
    end

    it 'does not serve outcomes after the query definition changes' do
      allow(SearchAnalytics::DailyQuery).to receive(:new).and_wrap_original do |method, **args|
        query = method.call(**args)
        fingerprints = query.fingerprints.merge('journey_outcomes' => 'changed')
        allow(query).to receive(:fingerprints).and_return(fingerprints)
        query
      end
      expect_parity
      expect(described_class.call(**arguments).value.payload.dig('availability', 'journey_outcomes')).to be(false)
    end

    it 'ignores a stale frontend fingerprint the same way as the existing reader' do
      SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'frontend_events').update(fingerprint: 'obsolete')
      expect_parity
    end

    it 'does not combine a new day with stale materialized views' do
      store_day(first_date - 1)
      expect(described_class.call(**arguments(from: first_date - 1)).available).to be(false)
    end

    it 'rejects an older materialized-view processing version' do
      stub_const('SearchAnalytics::MaterializedViews::VERSION', 0)
      expect(described_class.call(**arguments).available).to be(false)
    end
  end

  context 'without populated materialized views' do
    it 'uses the existing reader without starting a rebuild' do
      allow(SearchAnalytics::MaterializedViews).to receive(:ready?).and_return(false)
      expect(SearchAnalytics::MaterializedViews).not_to receive(:refresh!)
      expect(SearchAnalytics::DailyResults.call(**arguments)).to eq(SearchAnalytics::DailyResults.legacy_call(**arguments))
    end
  end

  context 'with XI data' do
    let(:service) { 'xi' }

    it 'preserves XI results and keeps frontend observations unsupported' do
      rebuild
      expect_parity
      expect(described_class.call(**arguments).value.payload.dig('frontend_events', 'coverage', 'supported')).to be(false)
    end
  end
end
