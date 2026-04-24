# frozen_string_literal: true

# Three targeted index additions for commodities#show:
#
# Index 1 & 2: partial indexes on base_regulations and modification_regulations
#   for the approved composite-key lookup pattern.
#
#   The eager-load queries for :base_regulation, :justification_base_regulation
#   and :modification_regulation all take the form:
#
#     WHERE approved_flag IS TRUE
#       AND (base_regulation_id, base_regulation_role) IN ((v1, v2), ...)
#
#   With separate single-column indexes, PostgreSQL may BitmapAnd the
#   approved_flag index (large) with the composite-key index (small) rather
#   than doing a direct index lookup. A partial index that covers only
#   approved rows collapses this into a single index scan.
#
# Index 3: fts_regulation_actions_oplog(stopped_regulation_id)
#
#   The full_temporary_stop_regulations eager-load joins the
#   fts_regulation_actions view and filters by stopped_regulation_id IN (...).
#   Because fts_regulation_actions is a view, the supporting index has to live
#   on the underlying fts_regulation_actions_oplog table. The only existing
#   index there is a four-column composite with stopped_regulation_id as the
#   third column, which cannot be used for this single-column predicate.

Sequel.migration do
  up do
    run <<-SQL
      CREATE INDEX IF NOT EXISTS base_regulations_approved_composite_index
        ON base_regulations (base_regulation_id, base_regulation_role)
        WHERE approved_flag IS TRUE;

      CREATE INDEX IF NOT EXISTS modification_regulations_approved_composite_index
        ON modification_regulations (modification_regulation_id, modification_regulation_role)
        WHERE approved_flag IS TRUE;

      CREATE INDEX IF NOT EXISTS fts_regulation_actions_stopped_regulation_id_index
        ON fts_regulation_actions_oplog (stopped_regulation_id);
    SQL
  end

  down do
    run <<-SQL
      DROP INDEX IF EXISTS base_regulations_approved_composite_index;
      DROP INDEX IF EXISTS modification_regulations_approved_composite_index;
      DROP INDEX IF EXISTS fts_regulation_actions_stopped_regulation_id_index;
    SQL
  end
end
