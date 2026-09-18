RSpec.describe 'Test database materialized view preparation', :truncation do
  it 'refreshes dependencies through ordinary views before dependent materialized views' do
    db = Sequel::Model.db
    db.run('CREATE SCHEMA analytics_refresh_order_spec')
    db.run('CREATE TABLE analytics_refresh_order_spec.source (id integer PRIMARY KEY)')
    db[Sequel.qualify(:analytics_refresh_order_spec, :source)].insert(id: 1)
    db.run('CREATE MATERIALIZED VIEW analytics_refresh_order_spec.z_parent AS SELECT id FROM analytics_refresh_order_spec.source WITH NO DATA')
    db.run('CREATE VIEW analytics_refresh_order_spec.bridge AS SELECT id FROM analytics_refresh_order_spec.z_parent')
    db.run('CREATE MATERIALIZED VIEW analytics_refresh_order_spec.a_child AS SELECT id FROM analytics_refresh_order_spec.bridge WITH NO DATA')

    task = Rake::Task['db:test:populate_empty_materialized_views']
    task.reenable
    task.invoke

    expect(db.fetch('SELECT id FROM analytics_refresh_order_spec.a_child').all).to eq([{ id: 1 }])
  ensure
    db&.run('DROP SCHEMA IF EXISTS analytics_refresh_order_spec CASCADE')
  end
end
