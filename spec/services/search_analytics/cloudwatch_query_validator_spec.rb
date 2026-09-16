RSpec.describe SearchAnalytics::CloudwatchQueryValidator do
  subject(:validate) do
    described_class.call(log_group_name: 'platform-logs-development', client:, now:, output:)
  end

  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:now) { Time.zone.parse('2026-07-23 10:00:00 UTC') }
  let(:output) { StringIO.new }
  let(:daily_definitions) do
    {
      'volume' => 'SELECT COUNT(*) FROM `platform-logs-development`',
      'trend' => "SELECT COUNT(*) FROM `platform-logs-development` GROUP BY DATE_TRUNC('HOUR', `@timestamp`)",
      'duplicate' => 'SELECT COUNT(*) FROM `platform-logs-development`',
    }
  end

  before do
    allow(SearchAnalytics::DailyQuery).to receive(:new).and_return(instance_double(SearchAnalytics::DailyQuery, query_definitions: daily_definitions))
    allow(client).to receive_messages(
      start_query: instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: 'query-id'),
      get_query_results: instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Complete'),
    )
  end

  it 'uses the daily query polling policy' do
    expect(described_class::QUERY_MAX_POLLS).to eq(SearchAnalytics::DailyQuery::QUERY_MAX_POLLS)
    expect(described_class::QUERY_POLL_INTERVAL_SECONDS).to eq(SearchAnalytics::DailyQuery::QUERY_POLL_INTERVAL_SECONDS)
  end

  it 'validates distinct daily queries, not the superseded rolling snapshots' do
    expect(SearchAnalytics::CloudwatchSnapshotQuery).not_to receive(:query_definitions)
    expect(validate).to be(true)
    expect(client).to have_received(:start_query).with(
      start_time: (now - 5.minutes).to_i, end_time: now.to_i,
      query_language: 'SQL', query_string: daily_definitions.fetch('volume')
    ).once
    expect(client).to have_received(:start_query).exactly(2).times
    expect(output.string).to include('Validated daily/volume, daily/duplicate', 'Validated 2 distinct CloudWatch queries')
  end

  it 'includes all real daily definitions without collecting or storing results' do
    allow(SearchAnalytics::DailyQuery).to receive(:new).and_call_original
    expect(Aws::CloudWatchLogs::Client).not_to receive(:new)
    expect(SearchAnalyticsQueryResult).not_to receive(:fetch)
    validate
    expect(output.string).to include('Validated daily/search_journeys', 'Validated daily/ai_cost_trend', "Validated #{TradeTariffBackend.service == 'uk' ? 9 : 8} distinct CloudWatch queries")
    expect(client).to have_received(:start_query).with(hash_including(query_string: a_string_including("request_source = 'frontend'", 'worker-uk/')))
  end

  it 'retains validation of rendered native dashboard queries' do
    described_class.call(log_group_name: 'platform-logs-development', client:, now:, output:,
                         dashboard_queries: { 'operations' => { 'query_language' => 'CWLI', 'query_string' => "SOURCE 'platform-logs-development' | stats count(*)" } })
    expect(client).to have_received(:start_query).with(hash_including(
                                                         log_group_name: 'platform-logs-development', query_language: 'CWLI', query_string: 'stats count(*)',
                                                       ))
  end

  it 'strips dashboard source envelopes from SQL before execution' do
    described_class.call(log_group_name: 'platform-logs-development', client:, now:, output:,
                         dashboard_queries: { 'overview' => { 'query_language' => 'SQL', 'query_string' => "SOURCE 'platform-logs-development' | SELECT COUNT(*) FROM `platform-logs-development`" } })
    expect(client).to have_received(:start_query).with(hash_including(query_language: 'SQL', query_string: daily_definitions.fetch('volume'))).twice
    expect(client).not_to have_received(:start_query).with(hash_including(:log_group_name))
  end

  it 'rejects an unexpected inner SQL source before execution' do
    daily_definitions.replace('wrong' => 'SELECT request_id FROM `platform-logs-development` WHERE request_id NOT IN (SELECT request_id FROM `production`)')
    expect { validate }.to raise_error(described_class::ValidationError, /different log group/)
    expect(client).not_to have_received(:start_query)
  end

  it 'polls until AWS completes the query' do
    allow(Kernel).to receive(:sleep)
    allow(client).to receive(:get_query_results).and_return(
      instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Running'),
      instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Complete'),
    )
    validate
    expect(client).to have_received(:get_query_results).exactly(3).times
    expect(Kernel).to have_received(:sleep).once
  end

  it 'reports terminal failures and continues validating other definitions' do
    allow(client).to receive(:get_query_results).and_return(
      instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Failed'),
      instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Complete'),
    )
    expect { validate }.to raise_error(described_class::ValidationError, /daily\/volume, daily\/duplicate: CloudWatch query Failed/)
    expect(client).to have_received(:start_query).twice
  end

  it 'reports a timeout after the polling limit' do
    stub_const("#{described_class}::QUERY_MAX_POLLS", 2)
    allow(Kernel).to receive(:sleep)
    allow(client).to receive(:get_query_results).and_return(instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Running'))
    expect { validate }.to raise_error(described_class::ValidationError, /timed out while polling/)
    expect(client).to have_received(:get_query_results).exactly(4).times
    expect(Kernel).to have_received(:sleep).exactly(2).times
  end

  it 'includes AWS compile locations for malformed queries' do
    compile_error = Aws::CloudWatchLogs::Types::QueryCompileError.new(
      message: 'unexpected symbol',
      location: Aws::CloudWatchLogs::Types::QueryCompileErrorLocation.new(start_char_offset: 12, end_char_offset: 18),
    )
    malformed = Aws::CloudWatchLogs::Errors::MalformedQueryException.allocate
    allow(malformed).to receive(:query_compile_error).and_return(compile_error)
    allow(client).to receive(:start_query).and_raise(malformed)
    expect { validate }.to raise_error(described_class::ValidationError, /unexpected symbol \(characters 12-18\)/)
  end
end
