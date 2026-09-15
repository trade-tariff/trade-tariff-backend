RSpec.describe 'Search analytics storage' do
  let(:collection) { create(:search_analytics_collection) }

  def query_run(**attributes)
    SearchAnalyticsQueryRun.create(
      collection_id: collection.id, name: 'volume', status: 'Complete', started_at: Time.current, **attributes,
    )
  end

  def query_result(**attributes)
    SearchAnalyticsQueryResult.create(
      collection_id: collection.id, service: collection.service, source: collection.source,
      reporting_date: collection.reporting_date, region: collection.region,
      log_group_name: collection.log_group_name, name: 'volume', fingerprint: 'query-definition',
      rows: Sequel.pg_jsonb([]), origin: 'collected', created_at: Time.current, **attributes
    )
  end

  it 'persists complete empty results independently of the execution ledger' do
    run = query_run(bytes_scanned: 5_000_000_000)
    result = query_result

    expect(run.refresh.bytes_scanned).to eq(5_000_000_000)
    expect(result.refresh.rows.to_a).to eq([])
    expect(result.collection_id).to eq(run.collection_id)
  end

  it 'retains multiple results for the same definition instead of overwriting history' do
    first = query_result
    second = query_result(rows: Sequel.pg_jsonb([{ 'searches' => '2' }]))

    expect(first.id).not_to eq(second.id)
    expect(SearchAnalyticsQueryResult.count).to eq(2)
    expect(first.refresh.rows.to_a).to eq([])
  end

  it 'stores the exact result references used for a publication' do
    result = query_result
    manifest = Sequel.pg_jsonb('volume' => result.id)
    collection.update(query_results: manifest)
    day = create(:search_analytics_day, collection_id: collection.id, facts: Sequel.pg_jsonb('query_results' => manifest))

    expect(collection.refresh.query_results.to_h).to eq('volume' => result.id)
    expect(day.refresh.facts['query_results']).to eq('volume' => result.id)
  end

  it 'prevents concurrent attempts for a day even across measurement definitions' do
    create(:search_analytics_collection, status: 'running', definition_version: 1)

    expect { create(:search_analytics_collection, status: 'running', definition_version: 2) }
      .to raise_error(Sequel::UniqueConstraintViolation)
  end

  it 'allows independent services, sources and dates to be collected' do
    create(:search_analytics_collection, status: 'running')
    create(:search_analytics_collection, status: 'running', service: 'xi')
    create(:search_analytics_collection, status: 'running', source: 'local')
    create(:search_analytics_collection, status: 'running', reporting_date: Date.new(2026, 9, 13))

    expect(SearchAnalyticsCollection.count).to eq(4)
  end

  it 'retains completed and failed attempts for the same publication identity' do
    create(:search_analytics_collection, status: 'complete')
    create(:search_analytics_collection, status: 'failed')
    create(:search_analytics_collection, status: 'running')

    expect(SearchAnalyticsCollection.count).to eq(3)
  end

  it 'prevents duplicate logical query names within an attempt' do
    query_run

    expect { query_run(query_id: 'another-submission') }.to raise_error(Sequel::UniqueConstraintViolation)
  end

  it 'prevents duplicate daily publications but permits a different definition' do
    create(:search_analytics_day, definition_version: 1)
    create(:search_analytics_day, definition_version: 2)

    expect { create(:search_analytics_day, definition_version: 2) }.to raise_error(Sequel::UniqueConstraintViolation)
  end

  it 'does not permit deleting collection provenance while query runs reference it' do
    query_run

    expect { collection.delete }.to raise_error(Sequel::ForeignKeyConstraintViolation)
  end

  it 'does not permit deleting collection provenance while reusable results reference it' do
    query_result

    expect { collection.delete }.to raise_error(Sequel::ForeignKeyConstraintViolation)
  end

  it 'does not permit deleting collection provenance while a day references it' do
    create(:search_analytics_day, collection_id: collection.id)

    expect { collection.delete }.to raise_error(Sequel::ForeignKeyConstraintViolation)
  end
end
