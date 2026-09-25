RSpec.describe SearchExport::CloudwatchReader do
  let(:from) { Date.new(2026, 9, 23) }
  let(:generated_at) { Time.utc(2026, 9, 24, 12) }
  let(:client) { Aws::CloudWatchLogs::Client.new(stub_responses: true) }
  let(:reader) { described_class.new(from:, to: from, generated_at:, client:) }
  let(:trace) do
    { event: 'evaluation_journey_recorded',
      request_id: 'guided-1',
      trace_version: SearchExport::JourneyProjection::TRACE_VERSION,
      query: 'chicken',
      terminal_at: '2026-09-23T10:00:00Z',
      end_page_type: 'Result',
      details: { expansion_terms: [], answers: [], results: [{ commodity_code: '0207141000', description: 'Frozen cuts', confidence_label: 'Strong' }] } }
  end

  before { client.stub_responses(:start_query, query_id: 'query-1') }

  def row(event, at: '2026-09-23T10:00:00Z')
    [{ field: '@timestamp', value: at }, { field: '@message', value: event.to_json }]
  end

  def response(*events)
    { status: 'Complete', statistics: { records_matched: events.size.to_f }, results: events.map { |event| row(event) } }
  end

  it 'joins backend selections only to guided terminal traces and orders journeys' do
    click = { event: 'result_selected', request_id: 'guided-1', goods_nomenclature_item_id: '0207141000' }
    client.stub_responses(:get_query_results, [response(trace), response(click, click.merge(request_id: 'classic-1'))])
    result = reader.call
    expect(result.journeys.map(&:request_id)).to eq(%w[guided-1])
    expect(result.clicks.keys).to eq(%w[guided-1])
    expect(result.clicks['guided-1'].first.commodity_code).to eq('0207141000')
    queries = client.api_requests.select { |request| request[:operation_name] == :start_query }
    expect(queries.size).to eq(2)
    expect(queries.first[:params][:query_string]).to include('request_source = "frontend"', 'ecs\\/(backend|worker)-uk\\/', 'jsonParse(@message)', 'toMillis(@timestamp) <')
    expect(queries.last[:params][:end_time]).to eq(generated_at.to_i)
  end

  it 'uses the latest terminal trace for each journey and excludes out-of-range terminals' do
    client.stub_responses(:get_query_results, response(trace, trace.merge(query: 'latest', terminal_at: '2026-09-23T11:00:00Z'), trace.merge(request_id: 'outside', terminal_at: '2026-09-24T10:00:00Z')))
    expect(reader.call.journeys.map(&:query)).to eq(%w[latest])
  end

  it 'marks a journey omitted when an associated failure is observed' do
    client.stub_responses(:get_query_results, response(trace, { event: 'search_stage_failed', request_id: 'guided-1' }))
    expect(reader.call.journeys.first.omitted).to be(true)
  end

  it 'does not treat an older trace version as reconstructable' do
    client.stub_responses(:get_query_results, response(trace.merge(trace_version: 'classification_evaluation_trace.v1')))
    expect(reader.call.journeys).to be_empty
  end

  it 'splits saturated windows rather than accepting a truncated result' do
    stub_const('SearchExport::CloudwatchReader::LIMIT', 2)
    client.stub_responses(:get_query_results, [response(trace, trace), response(trace), response, response])
    expect(reader.call.journeys.size).to eq(1)
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(4)
  end

  it 'splits when CloudWatch reports more matches than returned rows' do
    client.stub_responses(:get_query_results, [response(trace).merge(statistics: { records_matched: 3.0 }), response(trace), response, response])
    expect(reader.call.journeys.size).to eq(1)
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(4)
  end

  it 'fails instead of silently dropping saturation within a single second' do
    stub_const('SearchExport::CloudwatchReader::LIMIT', 1)
    client.stub_responses(:get_query_results, response(trace))
    expect { reader.call }.to raise_error(described_class::Error, /one second/)
  end

  it 'cancels an incomplete query at the deadline' do
    client.stub_responses(:get_query_results, status: 'Running')
    allow(reader).to receive(:monotonic_time).and_return(0, 0, 0, 601)
    allow(reader).to receive(:sleep)
    expect { reader.call }.to raise_error(described_class::Error, /timed out/)
    expect(client.api_requests.map { |request| request[:operation_name] }).to include(:stop_query)
  end

  it 'fails on query failure without returning partial data' do
    client.stub_responses(:get_query_results, [response(trace), { status: 'Failed' }])
    expect { reader.call }.to raise_error(described_class::Error, /could not complete/)
  end

  it 'rejects malformed trace data' do
    client.stub_responses(:get_query_results, response(trace.except(:details)))
    expect { reader.call }.to raise_error(described_class::Error, /complete journey logs/)
  end

  [
    { answers: nil },
    { answers: [{ question: 'Cut?', options: 'Whole', answer: 'Whole' }] },
    { results: ['not a result object'] },
  ].each do |invalid_details|
    it "rejects a malformed trace structure: #{invalid_details.keys.join(', ')}" do
      client.stub_responses(:get_query_results, response(trace.deep_merge(details: invalid_details)))
      expect { reader.call }.to raise_error(described_class::Error, /complete journey logs/)
    end
  end

  it 'bounds retrieved bytes' do
    stub_const('SearchExport::CloudwatchReader::MAX_BYTES', 1)
    client.stub_responses(:get_query_results, response(trace))
    expect { reader.call }.to raise_error(described_class::Error, /too large/)
  end

  it 'bounds the number of retained journeys' do
    stub_const('SearchExport::Workbook::MAX_ROWS', 0)
    client.stub_responses(:get_query_results, response(trace))
    expect { reader.call }.to raise_error(described_class::Error, /Too many journeys/)
  end

  it 'allows large scans to complete without a scan-volume budget' do
    client.stub_responses(:get_query_results, [
      { status: 'Running', statistics: { bytes_scanned: 11.gigabytes.to_f } },
      response(trace).merge(statistics: { records_matched: 1.0, bytes_scanned: 12.gigabytes.to_f }),
      response,
    ])
    allow(reader).to receive(:sleep)
    expect(reader.call.journeys.size).to eq(1)
  end

  it 'interprets CloudWatch timestamps as UTC' do
    event = { event: 'result_selected', request_id: 'guided-1', goods_nomenclature_item_id: '0207141000' }
    client.stub_responses(:get_query_results, response(trace).merge(results: [row(trace), row(event, at: '2026-09-23 12:00:00.000')]))
    expect(reader.call.clicks['guided-1'].first.clicked_at).to eq(Time.utc(2026, 9, 23, 12))
  end

  it 'limits query submissions' do
    stub_const('SearchExport::CloudwatchReader::MAX_QUERIES', 1)
    client.stub_responses(:get_query_results, response)
    expect { reader.call }.to raise_error(described_class::Error, /Too many log queries/)
  end

  it 'bounds late-click retrieval to the day after the requested range' do
    reader = described_class.new(from:, to: from, generated_at: generated_at + 30.days, client:)
    client.stub_responses(:get_query_results, response)
    reader.call
    queries = client.api_requests.select { |request| request[:operation_name] == :start_query }
    expect(queries.last[:params][:end_time]).to eq(Time.utc(2026, 9, 25).to_i)
  end
end
