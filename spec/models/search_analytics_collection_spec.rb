RSpec.describe SearchAnalyticsCollection do
  it 'keeps an empty attempt cost incomplete' do
    expect(create(:search_analytics_collection).cost_summary).to include(
      'known_bytes_scanned' => 0, 'known_estimated_cost_usd' => '0.0', 'cost_complete' => false,
    )
  end

  it 'reports no new scan charge when a complete collection only reused results' do
    attempt = create(:search_analytics_collection, query_results: Sequel.pg_jsonb('volume' => 42))
    expect(attempt.cost_summary).to include('known_estimated_cost_usd' => '0.0', 'cost_complete' => true)
  end

  it 'keeps running attempts incomplete even with final scan statistics' do
    attempt = create(:search_analytics_collection, status: 'running')
    SearchAnalyticsQueryRun.create(collection_id: attempt.id, name: 'volume', status: 'Complete', bytes_scanned: 1_000_000_000, started_at: Time.current)
    expect(attempt.cost_summary).to include('known_estimated_cost_usd' => '0.005', 'cost_complete' => false)
  end

  %w[Complete Failed Cancelled Timeout].each do |status|
    it "includes measured #{status} query charges in a finished attempt" do
      attempt = create(:search_analytics_collection, status: 'failed', price_per_gb_usd: '0.0059')
      SearchAnalyticsQueryRun.create(collection_id: attempt.id, name: 'volume', status:, bytes_scanned: 5_000_000_000, started_at: Time.current)
      expect(attempt.cost_summary).to include('known_estimated_cost_usd' => '0.0295', 'cost_complete' => true)
    end
  end

  %w[Submitting Scheduled Running Interrupted Unknown].each do |status|
    it "does not treat #{status} statistics as a reconciled charge" do
      attempt = create(:search_analytics_collection, status: 'failed')
      SearchAnalyticsQueryRun.create(collection_id: attempt.id, name: 'volume', status:, bytes_scanned: 1_000_000_000, started_at: Time.current)
      expect(attempt.cost_summary).to include('known_estimated_cost_usd' => '0.005', 'cost_complete' => false)
    end
  end

  it 'does not report complete costs for a day with no attempts' do
    expect(described_class.cost_for_day(reporting_date: Date.new(2026, 9, 14))).to include('attempts' => 0, 'cost_complete' => false)
  end

  it 'isolates daily cost totals by service, source and reporting date' do
    create(:search_analytics_collection, service: 'xi')
    create(:search_analytics_collection, source: 'local')
    create(:search_analytics_collection, reporting_date: Date.new(2026, 9, 13))
    expect(described_class.cost_for_day(reporting_date: Date.new(2026, 9, 14))).to include('attempts' => 0)
  end

  it 'includes superseded and failed attempts in the daily cost estimate' do
    first = create(:search_analytics_collection)
    second = create(:search_analytics_collection, status: 'failed', price_per_gb_usd: 0.01)
    [first, second].each do |attempt|
      SearchAnalyticsQueryRun.create(collection_id: attempt.id, name: 'volume', status: 'Complete', bytes_scanned: 1_000_000_000, started_at: Time.current)
    end

    expect(described_class.cost_for_day(reporting_date: first.reporting_date)).to include(
      'attempts' => 2, 'known_bytes_scanned' => 2_000_000_000,
      'known_estimated_cost_usd' => '0.015', 'cost_complete' => true
    )
  end

  it 'does not report a complete total when statistics are missing' do
    attempt = create(:search_analytics_collection, status: 'failed')
    SearchAnalyticsQueryRun.create(collection_id: attempt.id, name: 'volume', status: 'Interrupted', query_id: 'reconcile-me', started_at: Time.current)
    expect(attempt.cost_summary).to include('known_bytes_scanned' => 0, 'cost_complete' => false)
    expect(described_class.cost_for_day(reporting_date: attempt.reporting_date).fetch('cost_complete')).to be(false)
  end
end
