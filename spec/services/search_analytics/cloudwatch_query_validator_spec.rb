RSpec.describe SearchAnalytics::CloudwatchQueryValidator do
  subject(:validate) do
    described_class.call(
      log_group_name: 'platform-logs-development',
      client:,
      now:,
      output:,
    )
  end

  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:now) { Time.zone.parse('2026-07-23 10:00:00 UTC') }
  let(:output) { StringIO.new }

  before do
    allow(SearchAnalytics::CloudwatchSnapshotQuery).to receive(:query_definitions).and_return(
      { 'volume' => 'SELECT COUNT(*) FROM `platform-logs-development`' },
      { 'volume' => "SELECT COUNT(*) FROM `platform-logs-development` GROUP BY DATE_TRUNC('DAY', `@timestamp`)" },
      { 'volume' => "SELECT COUNT(*) FROM `platform-logs-development` GROUP BY DATE_TRUNC('DAY', `@timestamp`)" },
    )
    allow(client).to receive_messages(
      start_query: instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: 'query-id'),
      get_query_results: instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Complete'),
    )
  end

  it 'uses the snapshot query polling policy' do
    expect(described_class::QUERY_MAX_POLLS).to eq(SearchAnalytics::CloudwatchSnapshotQuery::QUERY_MAX_POLLS)
    expect(described_class::QUERY_POLL_INTERVAL_SECONDS).to eq(SearchAnalytics::CloudwatchSnapshotQuery::QUERY_POLL_INTERVAL_SECONDS)
  end

  it 'executes every distinct generated query against development AWS' do
    expect(validate).to be(true)
    expect(SearchAnalytics::CloudwatchSnapshotQuery).to have_received(:query_definitions).with(period: '24h', log_group_name: 'platform-logs-development')
    expect(SearchAnalytics::CloudwatchSnapshotQuery).to have_received(:query_definitions).with(period: '7d', log_group_name: 'platform-logs-development')
    expect(SearchAnalytics::CloudwatchSnapshotQuery).to have_received(:query_definitions).with(period: '30d', log_group_name: 'platform-logs-development')
    expect(client).to have_received(:start_query).with(
      start_time: (now - 5.minutes).to_i,
      end_time: now.to_i,
      query_language: 'SQL',
      query_string: 'SELECT COUNT(*) FROM `platform-logs-development`',
    ).once
    expect(client).to have_received(:start_query).with(
      start_time: (now - 5.minutes).to_i,
      end_time: now.to_i,
      query_language: 'SQL',
      query_string: "SELECT COUNT(*) FROM `platform-logs-development` GROUP BY DATE_TRUNC('DAY', `@timestamp`)",
    ).once
    expect(output.string).to include('Validated 2 distinct CloudWatch queries')
  end

  it 'validates rendered native dashboard queries alongside SQL snapshots' do
    described_class.call(log_group_name: 'platform-logs-development', client:, now:, output:,
                         dashboard_queries: { 'operations' => { 'query_language' => 'CWLI', 'query_string' => "SOURCE 'platform-logs-development' | stats count(*)" } })

    expect(client).to have_received(:start_query).with(hash_including(
                                                         log_group_name: 'platform-logs-development', query_language: 'CWLI', query_string: 'stats count(*)',
                                                       ))
  end

  it 'strips the dashboard source envelope from SQL before calling StartQuery' do
    described_class.call(log_group_name: 'platform-logs-development', client:, now:, output:,
                         dashboard_queries: { 'overview' => { 'query_language' => 'SQL', 'query_string' => "SOURCE 'platform-logs-development' | SELECT COUNT(*) FROM `platform-logs-development`" } })

    expect(client).to have_received(:start_query).with(hash_including(query_language: 'SQL', query_string: 'SELECT COUNT(*) FROM `platform-logs-development`')).twice
    expect(client).not_to have_received(:start_query).with(hash_including(:log_group_name))
  end

  it 'rejects an unexpected inner SQL source before executing it' do
    allow(SearchAnalytics::CloudwatchSnapshotQuery).to receive(:query_definitions).and_return(
      { 'wrong' => 'SELECT request_id FROM `platform-logs-development` WHERE request_id NOT IN (SELECT request_id FROM `production`)' },
    )

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

  it 'reports terminal query failures and continues validating' do
    allow(client).to receive(:get_query_results).and_return(
      instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Failed'),
      instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Complete'),
    )

    expect { validate }.to raise_error(
      described_class::ValidationError,
      a_string_including('24h/volume: CloudWatch query Failed (query ID: query-id)'),
    )
    expect(client).to have_received(:start_query).twice
  end

  it 'reports a timeout after the configured polling limit' do
    stub_const("#{described_class}::QUERY_MAX_POLLS", 2)
    allow(Kernel).to receive(:sleep)
    allow(client).to receive(:get_query_results).and_return(
      instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Running'),
    )

    expect { validate }.to raise_error(
      described_class::ValidationError,
      a_string_including('CloudWatch query timed out while polling (query ID: query-id)'),
    )
    expect(client).to have_received(:get_query_results).exactly(4).times
    expect(Kernel).to have_received(:sleep).exactly(2).times
  end

  it 'includes AWS compile details for malformed queries' do
    compile_error = Aws::CloudWatchLogs::Types::QueryCompileError.new(
      message: 'unexpected symbol',
      location: Aws::CloudWatchLogs::Types::QueryCompileErrorLocation.new(
        start_char_offset: 12,
        end_char_offset: 18,
      ),
    )
    malformed_query = Aws::CloudWatchLogs::Errors::MalformedQueryException.allocate

    allow(malformed_query).to receive(:query_compile_error).and_return(compile_error)
    allow(client).to receive(:start_query).and_raise(malformed_query)

    expect { validate }.to raise_error(
      described_class::ValidationError,
      a_string_including('unexpected symbol (characters 12-18)'),
    )
  end
end
