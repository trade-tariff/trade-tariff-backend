RSpec.describe SearchAnalytics::DailyQuery do
  let(:client) { Aws::CloudWatchLogs::Client.new(region: 'eu-west-2', stub_responses: true) }
  let(:options) { { reporting_date: Date.new(2026, 9, 14), now: Time.utc(2026, 9, 15), region: 'eu-west-2', log_group_name: 'example-logs', client: } }
  let(:empty) { { status: 'Complete', results: [], statistics: { records_matched: 0.0 } } }
  let(:row) { { 'request_ids' => '["journey-a","journey-b"]', 'journey_count' => '2', 'event_count' => '3', 'search_type' => 'classic' } }

  before { client.stub_responses(:start_query, query_id: 'selection-query') }

  def response(value, matched: 3)
    empty.merge(results: [value.map { |field, content| { field:, value: content } }], statistics: { records_matched: matched.to_f })
  end

  def starts = client.api_requests.select { |r| r[:operation_name] == :start_query }

  %w[selection_results selection_pages].each do |name|
    it "stores hashed #{name} identities and preserves all other query groups during force replacement" do
      client.stub_responses(:get_query_results, empty)
      described_class.call(**options, queries: %w[volume])
      previous = SearchAnalyticsQueryResult.where(name: 'volume').first.values
      2.times do
        client.stub_responses(:get_query_results, [response(row), *Array.new(7) { empty }])
        result = described_class.call(**options, queries: [name], force: true).fetch(name)
        expect(result.first['journey_keys']).to eq(%w[journey-a journey-b].map { |id| Digest::SHA256.hexdigest(id) })
        expect(result.to_json).not_to include('request_ids', 'journey-a', 'journey-b')
      end
      expect(SearchAnalyticsQueryResult.where(name: name).count).to eq(1)
      expect(SearchAnalyticsQueryResult.where(name: 'volume').first.values).to eq(previous)
      expect(starts.size).to eq(17)
    end

    it "splits truncated #{name} identity sets before storing" do
      incomplete = row.merge('request_ids' => '["journey-a"]')
      client.stub_responses(:get_query_results, [response(incomplete), response(row), empty, *Array.new(7) { empty }])
      expect(described_class.call(**options, queries: [name]).fetch(name).size).to eq(1)
      expect(starts.size).to eq(10)
    end

    it "preserves earlier #{name} results when collection fails" do
      client.stub_responses(:get_query_results, [response(row), *Array.new(7) { empty }])
      described_class.call(**options, queries: [name])
      previous = SearchAnalyticsQueryResult.where(name: name).first.values
      client.stub_responses(:get_query_results, status: 'Failed')
      expect { described_class.call(**options, queries: [name], force: true) }.to raise_error(described_class::QueryError)
      expect(SearchAnalyticsQueryResult.where(name: name).first.values).to eq(previous)
    end
  end

  it 'uses exact identifier counts rather than failure-subquery statistics for the result cohort' do
    client.stub_responses(:get_query_results, [response(row, matched: 12), *Array.new(7) { empty }])
    expect(described_class.call(**options, queries: %w[selection_results]).fetch('selection_results').size).to eq(1)
    expect(starts.size).to eq(8)
  end

  it 'still rejects missing completeness statistics for frontend page collection' do
    client.stub_responses(:get_query_results, response(row).merge(statistics: {}))
    expect { described_class.call(**options, queries: %w[selection_pages]) }.to raise_error(described_class::QueryError, /completeness statistics/)
  end

  it 'bounds frontend page partitions without substituting a backend stream or a raw unprefixed JSON parser' do
    client.stub_responses(:get_query_results, empty)
    described_class.call(**options, queries: %w[selection_pages])
    sql = starts.first[:params][:query_string]
    expect(sql).to include("`@logStream` LIKE '%ecs/frontend/%'", "`@timestamp` >= CAST('2026-09-14 00:00:00'", "`@timestamp` < CAST('2026-09-14 03:00:00'")
    expect(sql).to include('REGEXP_EXTRACT', '$.params.request_id', "page_status IN ('200', '304')")
    expect(sql).not_to include('backend-uk/', "event = 'result_selected'")
  end

  it 'leaves every existing query fingerprint unchanged' do
    collector = described_class.new(**options)
    existing = collector.query_definitions.except(*SearchAnalytics::SelectionRates::SOURCE_NAMES)
    expected = collector.fingerprints.except(*SearchAnalytics::SelectionRates::SOURCE_NAMES)
    allow(collector).to receive(:query_definitions).and_return(existing)
    expect(collector.fingerprints).to eq(expected)
  end
end
