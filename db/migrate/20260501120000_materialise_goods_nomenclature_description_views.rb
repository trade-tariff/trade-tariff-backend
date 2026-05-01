# frozen_string_literal: true

# Converts goods_nomenclature_descriptions and goods_nomenclature_description_periods
# from plain views to materialised views.
#
# As plain views each row evaluation triggers a correlated MAX(oid) subquery
# against the underlying oplog table. Profiling /goods_nomenclatures/section/16
# (chapters 84+85, ~3328 commodity descendants) showed ~10,644 SubPlan loops in
# the descriptions eager-load alone, accounting for ~100ms of a 552ms request.
#
# Materialising pre-computes the deduplicated rows and lets PostgreSQL satisfy
# the `goods_nomenclature_sid IN (...)` eager-load with a conventional index
# scan. Refresh is handled automatically by MaterializeViewHelper, which
# discovers all oplog models where `materialized? && actually_materialized?`
# returns true (see app/helpers/materialize_view_helper.rb).

Sequel.migration do
  up do
    # --- goods_nomenclature_description_periods ------------------------------

    drop_view :goods_nomenclature_description_periods

    create_view :goods_nomenclature_description_periods, <<~SQL, materialized: true
      SELECT goods_nomenclature_description_periods1.goods_nomenclature_description_period_sid,
             goods_nomenclature_description_periods1.goods_nomenclature_sid,
             goods_nomenclature_description_periods1.validity_start_date,
             goods_nomenclature_description_periods1.goods_nomenclature_item_id,
             goods_nomenclature_description_periods1.productline_suffix,
             goods_nomenclature_description_periods1.validity_end_date,
             goods_nomenclature_description_periods1.oid,
             goods_nomenclature_description_periods1.operation,
             goods_nomenclature_description_periods1.operation_date,
             goods_nomenclature_description_periods1.filename
      FROM uk.goods_nomenclature_description_periods_oplog goods_nomenclature_description_periods1
      WHERE goods_nomenclature_description_periods1.oid IN (
        SELECT max(goods_nomenclature_description_periods2.oid)
        FROM uk.goods_nomenclature_description_periods_oplog goods_nomenclature_description_periods2
        WHERE goods_nomenclature_description_periods1.goods_nomenclature_description_period_sid =
              goods_nomenclature_description_periods2.goods_nomenclature_description_period_sid
      )
      AND (goods_nomenclature_description_periods1.operation)::text <> 'D'::text
    SQL

    # Required by oplog plugin's refresh! path (REFRESH MATERIALIZED VIEW
    # CONCURRENTLY needs a unique index).
    add_index :goods_nomenclature_description_periods, :oid, unique: true
    # Covers eager-load `goods_nomenclature_sid IN (...)` plus the time_machine
    # `validity_start_date <= ?` filter in a single index range scan.
    add_index :goods_nomenclature_description_periods,
              %i[goods_nomenclature_sid validity_start_date]
    # Covers the join from descriptions on (period_sid, sid).
    add_index :goods_nomenclature_description_periods,
              %i[goods_nomenclature_description_period_sid goods_nomenclature_sid]

    # --- goods_nomenclature_descriptions -------------------------------------

    drop_view :goods_nomenclature_descriptions

    create_view :goods_nomenclature_descriptions, <<~SQL, materialized: true
      SELECT goods_nomenclature_descriptions1.goods_nomenclature_description_period_sid,
             goods_nomenclature_descriptions1.language_id,
             goods_nomenclature_descriptions1.goods_nomenclature_sid,
             goods_nomenclature_descriptions1.goods_nomenclature_item_id,
             goods_nomenclature_descriptions1.productline_suffix,
             goods_nomenclature_descriptions1.description,
             goods_nomenclature_descriptions1.oid,
             goods_nomenclature_descriptions1.operation,
             goods_nomenclature_descriptions1.operation_date,
             goods_nomenclature_descriptions1.filename
      FROM uk.goods_nomenclature_descriptions_oplog goods_nomenclature_descriptions1
      WHERE goods_nomenclature_descriptions1.oid IN (
        SELECT max(goods_nomenclature_descriptions2.oid)
        FROM uk.goods_nomenclature_descriptions_oplog goods_nomenclature_descriptions2
        WHERE goods_nomenclature_descriptions1.goods_nomenclature_sid =
              goods_nomenclature_descriptions2.goods_nomenclature_sid
          AND goods_nomenclature_descriptions1.goods_nomenclature_description_period_sid =
              goods_nomenclature_descriptions2.goods_nomenclature_description_period_sid
      )
      AND (goods_nomenclature_descriptions1.operation)::text <> 'D'::text
    SQL

    add_index :goods_nomenclature_descriptions, :oid, unique: true
    # Covers the join from periods on (period_sid, sid).
    add_index :goods_nomenclature_descriptions,
              %i[goods_nomenclature_description_period_sid goods_nomenclature_sid]
    # Covers eager-loads keyed on goods_nomenclature_sid alone.
    add_index :goods_nomenclature_descriptions, :goods_nomenclature_sid
  end

  down do
    drop_view(:goods_nomenclature_descriptions, materialized: true) if GoodsNomenclatureDescription.actually_materialized?
    drop_view(:goods_nomenclature_description_periods, materialized: true) if GoodsNomenclatureDescriptionPeriod.actually_materialized?

    create_or_replace_view :goods_nomenclature_description_periods, <<~SQL
      SELECT goods_nomenclature_description_periods1.goods_nomenclature_description_period_sid,
             goods_nomenclature_description_periods1.goods_nomenclature_sid,
             goods_nomenclature_description_periods1.validity_start_date,
             goods_nomenclature_description_periods1.goods_nomenclature_item_id,
             goods_nomenclature_description_periods1.productline_suffix,
             goods_nomenclature_description_periods1.validity_end_date,
             goods_nomenclature_description_periods1.oid,
             goods_nomenclature_description_periods1.operation,
             goods_nomenclature_description_periods1.operation_date,
             goods_nomenclature_description_periods1.filename
      FROM uk.goods_nomenclature_description_periods_oplog goods_nomenclature_description_periods1
      WHERE goods_nomenclature_description_periods1.oid IN (
        SELECT max(goods_nomenclature_description_periods2.oid)
        FROM uk.goods_nomenclature_description_periods_oplog goods_nomenclature_description_periods2
        WHERE goods_nomenclature_description_periods1.goods_nomenclature_description_period_sid =
              goods_nomenclature_description_periods2.goods_nomenclature_description_period_sid
      )
      AND (goods_nomenclature_description_periods1.operation)::text <> 'D'::text
    SQL

    create_or_replace_view :goods_nomenclature_descriptions, <<~SQL
      SELECT goods_nomenclature_descriptions1.goods_nomenclature_description_period_sid,
             goods_nomenclature_descriptions1.language_id,
             goods_nomenclature_descriptions1.goods_nomenclature_sid,
             goods_nomenclature_descriptions1.goods_nomenclature_item_id,
             goods_nomenclature_descriptions1.productline_suffix,
             goods_nomenclature_descriptions1.description,
             goods_nomenclature_descriptions1.oid,
             goods_nomenclature_descriptions1.operation,
             goods_nomenclature_descriptions1.operation_date,
             goods_nomenclature_descriptions1.filename
      FROM uk.goods_nomenclature_descriptions_oplog goods_nomenclature_descriptions1
      WHERE goods_nomenclature_descriptions1.oid IN (
        SELECT max(goods_nomenclature_descriptions2.oid)
        FROM uk.goods_nomenclature_descriptions_oplog goods_nomenclature_descriptions2
        WHERE goods_nomenclature_descriptions1.goods_nomenclature_sid =
              goods_nomenclature_descriptions2.goods_nomenclature_sid
          AND goods_nomenclature_descriptions1.goods_nomenclature_description_period_sid =
              goods_nomenclature_descriptions2.goods_nomenclature_description_period_sid
      )
      AND (goods_nomenclature_descriptions1.operation)::text <> 'D'::text
    SQL
  end
end
