# frozen_string_literal: true

# Guided journeys that open a tariff page directly end with a navigation
# outcome. Recreate the guided outcome counts so they exclude those journeys
# instead of counting them as abandonment. A populated view is populated again,
# so services that already use outcome rates do not need a manual bootstrap.
views = File.expand_path('../views', __dir__)

Sequel.migration do
  recreate = ::Kernel.lambda do |db, version|
    populated = db.fetch(<<~SQL).get(:relispopulated)
      SELECT matview.relispopulated
      FROM pg_class matview
      JOIN pg_namespace namespace ON namespace.oid = matview.relnamespace
      WHERE namespace.nspname = current_schema()
        AND matview.relkind = 'm'
        AND matview.relname = 'search_analytics_guided_outcome_counts'
    SQL

    db.run 'DROP MATERIALIZED VIEW IF EXISTS search_analytics_guided_outcome_counts'
    db.run File.read(File.join(views, "search_analytics_guided_outcome_counts_#{version}.sql"))
    db.run 'REFRESH MATERIALIZED VIEW search_analytics_guided_outcome_counts' if populated
  end

  up { recreate.call(self, 'v02') }
  down { recreate.call(self, 'v01') }
end
