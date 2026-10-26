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
    message = event.key?(:controller) ? "I, [#{at} #1]  INFO -- : [http-id] [request_country=GB] #{event.to_json}" : event.to_json
    [{ field: '@timestamp', value: at }, { field: '@message', value: message }]
  end

  def frontend_page(id: 'guided-1', code: '0207141000', status: 200, controller: 'CommoditiesController', action: 'show')
    { method: 'GET', controller:, action:, status:, request_id: 'http-id', search_request_id: id, params: { request_id: id, id: code } }
  end

  def response(*events)
    { status: 'Complete', statistics: { records_matched: events.size.to_f }, results: events.map { |event| row(event) } }
  end

  def start_queries = client.api_requests.select { |request| request[:operation_name] == :start_query }
  def visit_queries = start_queries.select { |request| request[:params][:query_string].include?('CommoditiesController') }
  def journey_queries = start_queries - visit_queries

  it 'joins page visits to result journeys without backend selections', :aggregate_failures do
    client.stub_responses(:get_query_results, [response(trace), response, response(frontend_page(status: '304'), frontend_page(id: 'classic-1')), response(frontend_page)])
    result = reader.call
    expect(result.journeys.map(&:request_id)).to eq(%w[guided-1])
    expect(result.opened_pages.transform_values { |pages| pages.map(&:commodity_code) }).to eq('guided-1' => %w[0207141000 0207141000])
    expect(journey_queries.first[:params][:query_string]).to include('request_source = "frontend"', 'ecs\\/(backend|worker)-uk\\/', 'toMillis(@timestamp) <')
    expect(journey_queries.first[:params][:query_string]).not_to include('result_selected', 'ecs\\/frontend')
    expect(visit_queries.first[:params]).to include(start_time: Time.utc(2026, 9, 23).to_i)
    expect(visit_queries.first[:params][:query_string]).to include('ecs\\/frontend\\/', '"action":"show"', '"request_id":"(guided-1)')
    expect(start_queries.last[:params][:end_time]).to eq(generated_at.to_i)
  end

  it 'ignores unsuccessful and unrelated page requests' do
    pages = [
      frontend_page(status: 302),
      frontend_page(status: 404),
      frontend_page(action: 'origin'),
      frontend_page(controller: 'HeadingsController'),
      frontend_page(id: 'other-journey').merge(request_id: 'guided-1'),
      frontend_page(code: nil),
    ]
    client.stub_responses(:get_query_results, [response(trace), response, response(*pages), response])
    expect(reader.call.opened_pages).to be_empty
  end

  it 'uses visit filters that match frontend request logs' do
    client.stub_responses(:get_query_results, response(trace))
    reader.call
    patterns = visit_queries.first[:params][:query_string].scan(%r{@message like /(.+?)/(?=\s|$)}).flatten
    expect(patterns.size).to eq(3)
    expect(patterns.map { |pattern| Regexp.new(pattern) }).to all(match(row(frontend_page).last[:value]))
  end

  it 'reads visits only for linkable result journeys' do
    no_result = trace.merge(request_id: 'no-result', end_page_type: 'No result', details: trace[:details].merge(results: []))
    client.stub_responses(:get_query_results, response(no_result, trace.merge(request_id: 'guided 1')))
    expect(reader.call.journeys.size).to eq(2)
    expect(visit_queries).to be_empty
  end

  it 'counts visits only within each journey visit window' do
    reader = described_class.new(from:, to: from + 1, generated_at: generated_at + 30.days, client:)
    later = trace.merge(request_id: 'guided-2', terminal_at: '2026-09-23T18:00:00Z')
    visits = response.merge(results: [
      row(frontend_page(id: 'guided-2'), at: '2026-09-23T11:00:00Z'),
      row(frontend_page(id: 'guided-2'), at: '2026-09-23T18:30:00Z'),
      row(frontend_page, at: '2026-09-23T10:30:00Z'),
      row(frontend_page, at: '2026-09-25T00:00:00Z'),
    ])
    client.stub_responses(:get_query_results, [response(trace, later), response, response, visits, response])
    pages = reader.call.opened_pages.transform_values { |values| values.map(&:opened_at) }
    expect(pages).to eq('guided-1' => [Time.utc(2026, 9, 23, 10, 30)], 'guided-2' => [Time.utc(2026, 9, 23, 18, 30)])
  end

  it 'queries each day only for journeys that can have visits then' do
    stub_const('SearchExport::CloudwatchReader::VISIT_BATCH_SIZE', 1)
    reader = described_class.new(from:, to: from + 1, generated_at: generated_at + 30.days, client:)
    client.stub_responses(:get_query_results, response(trace, trace.merge(request_id: 'guided-2-later', terminal_at: '2026-09-24T18:00:00Z')))
    reader.call
    expect(visit_queries.map { |request| [Time.find_zone!('UTC').at(request[:params][:start_time]).to_date.iso8601, request[:params][:query_string][/"request_id":"\(([^)]*)\)/, 1]] })
      .to eq([%w[2026-09-23 guided-1], %w[2026-09-24 guided-1], %w[2026-09-24 guided-2], %w[2026-09-25 guided-2]])
  end

  it 'keeps full visit queries within the CloudWatch length limit' do
    traces = Array.new(described_class::VISIT_BATCH_SIZE + 1) { trace.merge(request_id: SecureRandom.uuid) }
    client.stub_responses(:get_query_results, [response(*traces), response])
    reader.call
    expect(visit_queries.size).to eq(4)
    expect(visit_queries.map { |request| request[:params][:query_string].length }).to all(be <= 10_000)
  end

  it 'fails before reading visits when the projected scan exceeds 500 GiB' do
    client.stub_responses(:get_query_results, [
      response(trace).merge(statistics: { records_matched: 1.0, bytes_scanned: 200.gigabytes.to_f }),
      response.merge(statistics: { records_matched: 0.0, bytes_scanned: 100.gigabytes.to_f }),
    ])
    expect { reader.call }.to raise_error(described_class::Error, /would exceed 500 GiB/)
    expect(visit_queries).to be_empty
  end

  it 'fails when a visit query does not complete' do
    client.stub_responses(:get_query_results, [response(trace), response, { status: 'Failed' }])
    expect { reader.call }.to raise_error(described_class::Error, /could not complete/)
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
    expect(journey_queries.size).to eq(4)
  end

  it 'splits when CloudWatch reports more matches than returned rows' do
    client.stub_responses(:get_query_results, [response(trace).merge(statistics: { records_matched: 3.0 }), response(trace), response, response])
    expect(reader.call.journeys.size).to eq(1)
    expect(journey_queries.size).to eq(4)
  end

  it 'fails instead of silently dropping saturation within a single second' do
    stub_const('SearchExport::CloudwatchReader::LIMIT', 1)
    client.stub_responses(:get_query_results, response(trace))
    expect { reader.call }.to raise_error(described_class::Error, /one second/)
  end

  it 'allows queries longer than the former ten-minute limit' do
    client.stub_responses(:get_query_results, [{ status: 'Running' }, response(trace)])
    allow(reader).to receive(:sleep) { travel 11.minutes }
    expect(reader.call.journeys.size).to eq(1)
  ensure
    travel_back
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

  it 'accepts retrieved messages beyond the former byte limit' do
    message = trace.to_json
    allow(message).to receive(:bytesize).and_return(101.megabytes)
    fields = [
      Aws::CloudWatchLogs::Types::ResultField.new(field: '@timestamp', value: '2026-09-23T10:00:00Z'),
      Aws::CloudWatchLogs::Types::ResultField.new(field: '@message', value: message),
    ]
    result = Aws::CloudWatchLogs::Types::GetQueryResultsResponse.new(
      status: 'Complete', results: [fields],
      statistics: Aws::CloudWatchLogs::Types::QueryStatistics.new(records_matched: 1.0)
    )
    allow(client).to receive(:get_query_results).and_return(result)

    expect(reader.call.journeys.map(&:request_id)).to eq(%w[guided-1])
  end

  it 'allows large scans below the generous scan limit' do
    client.stub_responses(:get_query_results, [
      { status: 'Running', statistics: { bytes_scanned: 11.gigabytes.to_f } },
      response(trace).merge(statistics: { records_matched: 1.0, bytes_scanned: 12.gigabytes.to_f }),
      response,
    ])
    allow(reader).to receive(:sleep)
    expect(reader.call.journeys.size).to eq(1)
  end

  it 'counts cumulative query statistics once across repeated polls' do
    client.stub_responses(:get_query_results, [
      { status: 'Running', statistics: { bytes_scanned: 150.gigabytes.to_f } },
      { status: 'Running', statistics: { bytes_scanned: 150.gigabytes.to_f } },
      response(trace).merge(statistics: { records_matched: 1.0, bytes_scanned: 200.gigabytes.to_f }),
      response.merge(statistics: { records_matched: 0.0, bytes_scanned: 50.gigabytes.to_f }),
      response,
    ])
    allow(reader).to receive(:sleep)
    expect(reader.call.journeys.size).to eq(1)
  end

  it 'cancels an active query when cumulative scanning exceeds 500 GiB' do
    client.stub_responses(:get_query_results, [
      response(trace).merge(statistics: { records_matched: 1.0, bytes_scanned: 400.gigabytes.to_f }),
      { status: 'Running', statistics: { bytes_scanned: 101.gigabytes.to_f } },
    ])
    expect { reader.call }.to raise_error(described_class::Error, /500 GiB/)
    expect(client.api_requests.count { |request| request[:operation_name] == :stop_query }).to eq(1)
  end

  it 'rejects completed results that exceed the scan limit' do
    client.stub_responses(:get_query_results, response(trace).merge(statistics: { records_matched: 1.0, bytes_scanned: 501.gigabytes.to_f }))
    expect { reader.call }.to raise_error(described_class::Error, /500 GiB/)
    expect(client.api_requests.map { |request| request[:operation_name] }).not_to include(:stop_query)
  end

  it 'cancels an active query at forty minutes' do
    allow(reader).to receive(:monotonic_time).and_return(0, 0, 0, 0, 2400)
    allow(reader).to receive(:sleep)
    client.stub_responses(:get_query_results, status: 'Running')
    expect { reader.call }.to raise_error(described_class::Error, /40 minutes/)
    expect(client.api_requests.map { |request| request[:operation_name] }).to include(:stop_query)
  end

  it 'interprets frontend CloudWatch timestamps as UTC' do
    visit = response.merge(results: [row(frontend_page, at: '2026-09-23 12:00:00.000')])
    client.stub_responses(:get_query_results, [response(trace), response, visit, response])
    expect(reader.call.opened_pages['guided-1'].map(&:opened_at)).to eq([Time.utc(2026, 9, 23, 12)])
  end

  it 'submits more than 512 queries when the date range needs them' do
    reader = described_class.new(from: from - 512, to: from, generated_at:, client:)
    client.stub_responses(:get_query_results, response)
    expect(reader.call.journeys).to be_empty
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(514)
  end

  it 'bounds journey and visit retrieval to the day after the range' do
    reader = described_class.new(from:, to: from, generated_at: generated_at + 30.days, client:)
    client.stub_responses(:get_query_results, response(trace))
    reader.call
    end_times = [journey_queries, visit_queries].map { |queries| JSON.parse(queries.last[:context].http_request.body_contents)['endTime'] }
    expect(end_times).to eq([Time.utc(2026, 9, 25).to_i] * 2)
  end
end
