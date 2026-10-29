RSpec.describe SearchAnalytics::ResultOffersQuery do
  let(:db) { Sequel::Model.db }
  let(:columns) { { request_id: 'text', service: 'text', event: 'text', search_type: 'text', request_source: 'text', skip_question: 'boolean', result_rank: 'bigint', confidence: 'text', '@logStream': 'text' } }

  def offer(**attributes)
    { request_id: 'guided', service: 'search', event: 'result_offered', search_type: 'interactive', request_source: 'frontend', skip_question: nil, result_rank: 1, confidence: 'strong', '@logStream': 'ecs/backend-uk/test' }.merge(attributes)
  end

  it 'counts only guided frontend offers on the selected service streams' do
    events = [offer,
              offer,
              offer(result_rank: 6, confidence: 'possible', '@logStream': 'ecs/worker-uk/test'),
              offer(event: 'answer_returned'),
              offer(search_type: 'internal'),
              offer(request_source: 'admin'),
              offer('@logStream': 'ecs/backend-xi/test'),
              offer(result_rank: nil),
              offer(request_id: 'classic-hybrid'),
              offer(request_id: 'classic-hybrid', event: 'interactive_configuration_used', skip_question: true)]
    values = events.map { |row| "(#{columns.map { |name, type| "#{db.literal(row.fetch(name))}::#{type}" }.join(', ')})" }
    names = columns.keys.map { |name| db.literal(Sequel.identifier(name)) }.join(', ')
    sql = described_class.call(source: 'events', log_stream_filter: "(`@logStream` LIKE '%ecs/backend-uk/%' OR `@logStream` LIKE '%ecs/worker-uk/%')").tr('`', '"')
    expect(db.fetch("WITH events(#{names}) AS (VALUES #{values.join(', ')}) #{sql}").all).to contain_exactly(
      { result_rank: 1, confidence: 'strong', event_count: 2 },
      { result_rank: 6, confidence: 'possible', event_count: 1 },
    )
  end

  it 'collects only offers without storing request identifiers' do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    client = Aws::CloudWatchLogs::Client.new(region: 'eu-west-2', stub_responses: true)
    client.stub_responses(:start_query, query_id: 'offers')
    fields = { 'result_rank' => '6', 'confidence' => 'possible', 'event_count' => '3' }
    client.stub_responses(:get_query_results, status: 'Complete', results: [fields.map { |field, value| { field:, value: } }], statistics: { records_matched: 200.0 })
    options = { reporting_date: Date.new(2026, 9, 14), now: Time.utc(2026, 9, 15), region: 'eu-west-2', client:, queries: %w[result_offers] }
    expect(SearchAnalytics::DailyQuery.call(**options)).to eq('result_offers' => [fields])
    expect(SearchAnalyticsQueryResult.select_map(:name)).to eq(%w[result_offers])
    expect(client.api_requests.first[:params][:query_string]).to include('UNIX_TIMESTAMP(`@timestamp`) >=', "request_source = 'frontend'")
    expect(SearchAnalytics::DailyQuery.call(**options)).to eq('result_offers' => [fields])
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(1)
  end
end
