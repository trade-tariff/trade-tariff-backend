# frozen_string_literal: true

# Add INCLUDE (oid) to the natural-key indexes on full_temporary_stop_regulations_oplog
# and fts_regulation_actions_oplog so that the correlated MAX(oid) subquery inside
# each view's WHERE clause can be satisfied with an index-only scan.
#
# Both oplog views deduplicate historical rows with a correlated subquery of the form:
#
#   WHERE oid IN (
#     SELECT MAX(t2.oid) FROM <table>_oplog t2
#     WHERE t2.<natural_key_cols> = t1.<natural_key_cols>
#   )
#
# The natural-key indexes cover the WHERE predicate, but without oid in the index
# PostgreSQL must heap-fetch each matching row to read oid before computing MAX.
# On production oplog tables that accumulate one row per CDS sync (years of history),
# this correlated subquery accounts for ~600ms per commodity request.
#
# With INCLUDE (oid), the aggregate is computed directly from the index leaf pages —
# no heap access — reducing the correlated subquery to a sub-millisecond index-only scan.

Sequel.migration do
  up do
    run <<-SQL
      DROP INDEX IF EXISTS full_temp_stop_reg_pk;
      CREATE INDEX full_temp_stop_reg_pk
        ON full_temporary_stop_regulations_oplog
        USING btree (full_temporary_stop_regulation_id, full_temporary_stop_regulation_role)
        INCLUDE (oid);

      DROP INDEX IF EXISTS fts_reg_act_pk;
      CREATE INDEX fts_reg_act_pk
        ON fts_regulation_actions_oplog
        USING btree (fts_regulation_id, fts_regulation_role, stopped_regulation_id, stopped_regulation_role)
        INCLUDE (oid);
    SQL
  end

  down do
    run <<-SQL
      DROP INDEX IF EXISTS full_temp_stop_reg_pk;
      CREATE INDEX full_temp_stop_reg_pk
        ON full_temporary_stop_regulations_oplog
        USING btree (full_temporary_stop_regulation_id, full_temporary_stop_regulation_role);

      DROP INDEX IF EXISTS fts_reg_act_pk;
      CREATE INDEX fts_reg_act_pk
        ON fts_regulation_actions_oplog
        USING btree (fts_regulation_id, fts_regulation_role, stopped_regulation_id, stopped_regulation_role);
    SQL
  end
end
