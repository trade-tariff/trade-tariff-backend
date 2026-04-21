# frozen_string_literal: true

# Both `measures` and `measure_excluded_geographical_areas` are materialized
# views, so we use raw SQL rather than alter_table.
#
# Index 1: measures(goods_nomenclature_sid, validity_start_date, validity_end_date)
#
#   The time-machine filter on the measures view is:
#     goods_nomenclature_sid IN (...) AND validity_start_date <= :date
#       AND (validity_end_date >= :date OR validity_end_date IS NULL)
#
#   Before this migration, PostgreSQL resolves that with a BitmapAnd across
#   three separate single-column indexes. A composite index covering all three
#   columns in access order lets the planner do a single index range scan —
#   particularly valuable on commodities#show, which eagerly loads measures for
#   the commodity and all its ancestors (typically 4–6 goods_nomenclature_sids).
#
# Index 2: measure_excluded_geographical_areas(measure_sid)
#
#   The excluded geographical areas CTE query joins
#   measure_excluded_geographical_areas on measure_sid. The existing composite
#   index (measure_sid, excluded_geographical_area, geographical_area_sid) has
#   measure_sid as its leading column, but a narrower dedicated index is smaller,
#   fits in cache more easily, and is more reliably chosen by the planner when
#   measure_sid is the only predicate column (e.g. for hash joins against the
#   CTE filter_ids set).

Sequel.migration do
  up do
    run <<-SQL
      CREATE INDEX IF NOT EXISTS measures_goods_nomenclature_sid_validity_composite_index
        ON measures (goods_nomenclature_sid, validity_start_date, validity_end_date);

      CREATE INDEX IF NOT EXISTS measure_excluded_geographical_areas_measure_sid_index
        ON measure_excluded_geographical_areas (measure_sid);
    SQL
  end

  down do
    run <<-SQL
      DROP INDEX IF EXISTS measures_goods_nomenclature_sid_validity_composite_index;
      DROP INDEX IF EXISTS measure_excluded_geographical_areas_measure_sid_index;
    SQL
  end
end
