# frozen_string_literal: true

# `goods_nomenclature_description_periods` and `goods_nomenclature_descriptions`
# are regular SQL views that inline a correlated MAX(oid) subquery to deduplicate
# the oplog tables:
#
#   WHERE oid IN (
#     SELECT MAX(oid) FROM ...oplog
#     WHERE primary_key_col = outer.primary_key_col
#   )
#
# Unlike `measures` (which uses `materialized: true` on the oplog plugin and
# pre-computes the deduplicated rows into a stored materialized view), these
# views re-execute the MAX(oid) correlated subquery for every row returned by
# the outer query.
#
# When the goods_nomenclature_descriptions many_to_many association is eager-
# loaded for a chapter or heading (which can push 500+ goods_nomenclature_sids
# into the IN list), the view returns ~1700 period rows and must execute a
# correlated subquery per row — ~3400 subquery executions in total.
#
# Both deduplication lookups already use an index for the WHERE clause, but
# they still need to scan all matching rows to compute MAX(oid):
#
#   gono_desc_primary_key  (goods_nomenclature_description_period_sid)
#   gono_desc_pk           (goods_nomenclature_sid,
#                           goods_nomenclature_description_period_sid)
#
# Adding `oid DESC` as a trailing column turns each MAX(oid) aggregate into a
# single-row index-only forward scan: the planner reads the first entry at the
# top of the (key, oid DESC) B-tree and returns immediately.
#
# The long-term fix is to convert both models to materialized views by adding
# `materialized: true` to their `plugin :oplog` declarations (as measures does),
# which eliminates the correlated subqueries entirely. That is a larger change
# and is tracked separately.

Sequel.migration do
  up do
    run <<-SQL
      -- Covers: SELECT MAX(oid) FROM goods_nomenclature_description_periods_oplog
      --         WHERE goods_nomenclature_description_period_sid = ?
      CREATE INDEX IF NOT EXISTS gono_desc_periods_oid_index
        ON goods_nomenclature_description_periods_oplog
        (goods_nomenclature_description_period_sid, oid DESC);

      -- Covers: SELECT MAX(oid) FROM goods_nomenclature_descriptions_oplog
      --         WHERE goods_nomenclature_sid = ? AND goods_nomenclature_description_period_sid = ?
      CREATE INDEX IF NOT EXISTS gono_desc_oid_index
        ON goods_nomenclature_descriptions_oplog
        (goods_nomenclature_sid, goods_nomenclature_description_period_sid, oid DESC);
    SQL
  end

  down do
    run <<-SQL
      DROP INDEX IF EXISTS gono_desc_periods_oid_index;
      DROP INDEX IF EXISTS gono_desc_oid_index;
    SQL
  end
end
