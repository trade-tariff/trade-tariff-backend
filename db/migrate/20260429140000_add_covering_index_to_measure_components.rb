# frozen_string_literal: true

# Replaces the single-column measure_sid index on the measure_components
# materialized view with a composite covering index.
#
# The hot query is:
#
#   SELECT * FROM measure_components
#   WHERE measure_sid IN (...)
#   ORDER BY duty_expression_id
#
# With the old index (measure_sid only), PostgreSQL does an Index Scan to
# locate rows by measure_sid and then fetches each matched row from the heap.
# With 64 measure_sid values and ~80 result rows scattered across many heap
# pages, this causes ~80 random page reads — explaining the high index-scan
# cost (450 cost units for 80 rows) seen in EXPLAIN output.
#
# The new index is:
#
#   (measure_sid, duty_expression_id)
#   INCLUDE (duty_amount, monetary_unit_code, measurement_unit_code,
#            measurement_unit_qualifier_code, filename)
#
# The INCLUDE columns are all remaining columns that Sequel selects (the oplog
# plugin strips oid, operation, operation_date). With all selected columns
# present in the index, PostgreSQL can use an Index Only Scan — it never
# touches the heap at all. Materialized views are always fully all-visible
# after a REFRESH, so index-only scans work unconditionally.
#
# The old single-column measure_sid index is dropped; the new composite index
# subsumes it (measure_sid is the leading key column) so no query regresses.

Sequel.migration do
  up do
    run <<~SQL
      CREATE INDEX IF NOT EXISTS measure_components_covering_index
        ON measure_components (measure_sid, duty_expression_id)
        INCLUDE (duty_amount, monetary_unit_code, measurement_unit_code,
                 measurement_unit_qualifier_code, filename);

      DROP INDEX IF EXISTS measure_components_measure_sid_index;
    SQL
  end

  down do
    run <<~SQL
      DROP INDEX IF EXISTS measure_components_covering_index;

      CREATE INDEX IF NOT EXISTS measure_components_measure_sid_index
        ON measure_components (measure_sid);
    SQL
  end
end
