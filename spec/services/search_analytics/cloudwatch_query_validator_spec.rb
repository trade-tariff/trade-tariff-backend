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
      { 'volume' => 'fields event | stats count(*)' },
      { 'volume' => 'fields event | stats count(*) by bin(1d)' },
      { 'volume' => 'fields event | stats count(*) by bin(1d)' },
    )
    allow(client).to receive_messages(
      start_query: instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: 'query-id'),
      get_query_results: instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Complete'),
    )
  end

  it 'executes every distinct generated query against development AWS' do
    expect(validate).to be(true)
    expect(SearchAnalytics::CloudwatchSnapshotQuery).to have_received(:query_definitions).with(period: '24h')
    expect(SearchAnalytics::CloudwatchSnapshotQuery).to have_received(:query_definitions).with(period: '7d')
    expect(SearchAnalytics::CloudwatchSnapshotQuery).to have_received(:query_definitions).with(period: '30d')
    expect(client).to have_received(:start_query).with(
      log_group_name: 'platform-logs-development',
      start_time: (now - 5.minutes).to_i,
      end_time: now.to_i,
      query_language: 'CWLI',
      query_string: 'fields event | stats count(*)',
    ).once
    expect(client).to have_received(:start_query).with(
      log_group_name: 'platform-logs-development',
      start_time: (now - 5.minutes).to_i,
      end_time: now.to_i,
      query_language: 'CWLI',
      query_string: 'fields event | stats count(*) by bin(1d)',
    ).once
    expect(output.string).to include('Validated 2 distinct CloudWatch queries')
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
      a_string_including('24h/volume: CloudWatch query Failed'),
    )
    expect(client).to have_received(:start_query).twice
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
