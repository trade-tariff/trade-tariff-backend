RSpec.describe SearchAnalytics::SelectionQuery do
  let(:db) { Sequel::Model.db }
  let(:collector) { SearchAnalytics::DailyQuery.new(reporting_date: Date.new(2026, 9, 14), region: 'eu-west-2', log_group_name: 'search_events') }
  let(:columns) do
    { request_id: 'text',
      service: 'text',
      event: 'text',
      search_type: 'text',
      request_source: 'text',
      result_count: 'bigint',
      results_type: 'text',
      final_result_type: 'text',
      search_degraded: 'boolean',
      '@logStream': 'text',
      '@message': 'text' }
  end

  before { allow(TradeTariffBackend).to receive(:service).and_return('uk') }

  def event(id, **attributes)
    { request_id: id,
      service: 'search',
      event: 'search_completed',
      search_type: 'classic',
      request_source: 'frontend',
      result_count: 1,
      results_type: 'fuzzy_search',
      final_result_type: nil,
      search_degraded: false,
      '@logStream': 'ecs/backend-uk/test',
      '@message': '{}' }.merge(attributes)
  end

  def execute(name, events)
    sql = collector.query_definitions.fetch(name).tr('`', '"')
      .gsub('TO_JSON(COLLECT_SET(request_id))', 'to_json(array_agg(DISTINCT request_id))')
    # Translate only CloudWatch's JSON functions; execute the actual predicates.
    %w[params.request_id controller action status].each do |field|
      cloudwatch = "GET_JSON_OBJECT(REGEXP_EXTRACT(\"@message\", '([{].*[}])', 1), '$.#{field}')"
      sql = sql.gsub(cloudwatch, "(substring(\"@message\" from '([{].*[}])')::jsonb #>> '{#{field.tr('.', ',')}}')")
    end
    values = events.map { |row| "(#{columns.map { |name, type| "#{db.literal(row.fetch(name))}::#{type}" }.join(', ')})" }
    names = columns.keys.map { |name| db.literal(Sequel.identifier(name)) }.join(', ')
    db.fetch("WITH search_events(#{names}) AS (VALUES #{values.join(', ')}) #{sql}").all.flat_map { |row|
      ids = row[:request_ids]
      ids.is_a?(String) ? JSON.parse(ids) : ids.to_a
    }.sort
  end

  it 'requires identified frontend fuzzy results, including single chapter or heading results, but not navigation or empty searches' do
    events = [
      event('chapter'),
      event('heading', result_count: 2),
      event('commodity'),
      event('commodity'),
      event('exact', results_type: 'exact_search'),
      event('empty', result_count: 0),
      event('negative', result_count: -1),
      event('missing', result_count: nil),
      event(nil),
      event(''),
      event('api', request_source: 'backend_only'),
      event('unknown', request_source: nil),
      event('xi', '@logStream': 'ecs/backend-xi/test'),
    ]
    expect(execute('selection_results', events)).to eq(%w[chapter commodity heading])
  end

  it 'counts final Internal results once, not question steps, errors or direct matches' do
    base = { search_type: 'interactive', results_type: 'hybrid' }
    events = [
      event('answers', **base, final_result_type: 'questions', result_count: 20),
      event('answers', **base, final_result_type: 'answers'),
      event('answers', **base, final_result_type: 'answers'),
      event('questions', **base, final_result_type: 'questions', result_count: 20),
      event('empty', **base, final_result_type: 'answers', result_count: 0),
      event('error', **base, final_result_type: 'error'),
      event('exact', **base, results_type: 'exact_match'),
      event('legacy', search_type: 'internal', results_type: 'opensearch'),
      event('blank', search_type: 'internal', results_type: 'vector', final_result_type: ''),
      event('unknown', **base, final_result_type: 'other'),
    ]
    expect(execute('selection_results', events)).to eq(%w[answers blank legacy])
  end

  it 'excludes failure and degradation cohorts and permits healthy worker-stream completions' do
    events = [event('ok', '@logStream': 'ecs/worker-uk/test'),
              event('failed'),
              event('failed', event: 'search_failed'),
              event('stage'),
              event('stage', event: 'search_stage_failed'),
              event('degraded', search_degraded: true)]
    expect(execute('selection_results', events)).to eq(%w[ok])
  end

  it 'uses linked successful frontend pages, including cached 304s, rather than backend misses or HTTP request IDs' do
    pages = [
      ['commodity', 'CommoditiesController', 200],
      ['heading', 'HeadingsController', 200],
      ['chapter', 'ChaptersController', 304],
      ['redirect', 'HeadingsController', 302],
      ['missing', 'CommoditiesController', 404],
      ['error', 'CommoditiesController', 500],
      ['search-page', 'SearchController', 200],
      [nil, 'CommoditiesController', 200],
      ['', 'CommoditiesController', 200],
    ].map do |id, controller, status|
      message = { request_id: 'unrelated-http-id', controller:, action: 'show', status:, params: { request_id: id } }
      event(nil, '@logStream': 'ecs/frontend/test', '@message': "INFO [http-id] [GB] #{message.to_json}")
    end
    expect(execute('selection_pages', pages)).to eq(%w[chapter commodity heading])
  end
end
