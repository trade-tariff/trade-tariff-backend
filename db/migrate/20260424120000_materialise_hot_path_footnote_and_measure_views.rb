# frozen_string_literal: true

# Converts five high-traffic plain views to materialized views.
#
# All five are queried on every commodity/heading/subheading show request:
#
#   footnotes                  — eager-loaded on goods nomenclatures and measures
#   footnote_description_periods — join table for footnote description loading
#   footnote_descriptions      — loaded alongside footnote_description_periods
#   measure_conditions         — eager-loaded for every measure
#   measure_components         — eager-loaded for every measure (duty components)
#
# As plain views each row evaluation triggers a correlated MAX(oid) subquery
# against the underlying oplog table. Materializing pre-computes the
# deduplicated rows and allows PostgreSQL to use conventional indexes for all
# subsequent queries.
#
# Refresh is handled automatically: MaterializeViewHelper#refresh_materialized_view
# iterates all oplog models with materialized: true and is called at the end of
# both TaricUpdatesSynchronizerWorker and CdsUpdatesSynchronizerWorker, as well
# as ApplyWorker and RollbackWorker.
#
# simplified_procedural_code_measures is a plain view that JOINs
# measure_components by name. PostgreSQL tracks this as a dependency and will
# refuse DROP VIEW measure_components unless we drop the dependent view first.
# It is recreated after the measure_components conversion.

Sequel.migration do
  up do
    # --- footnotes -----------------------------------------------------------

    drop_view :footnotes

    create_view :footnotes, <<~SQL, materialized: true
      SELECT footnote_id,
             footnote_type_id,
             validity_start_date,
             validity_end_date,
             "national",
             oid,
             operation,
             operation_date,
             filename
      FROM uk.footnotes_oplog footnotes1
      WHERE oid IN (
        SELECT max(footnotes2.oid)
        FROM uk.footnotes_oplog footnotes2
        WHERE footnotes1.footnote_type_id::text = footnotes2.footnote_type_id::text
          AND footnotes1.footnote_id::text = footnotes2.footnote_id::text
      )
      AND operation::text <> 'D'
    SQL

    # Unique OID index is required by the oplog plugin's refresh! path and
    # allows REFRESH MATERIALIZED VIEW CONCURRENTLY in future.
    add_index :footnotes, :oid, unique: true
    # Covers (footnote_type_id, footnote_id) IN (...) batched eager loads.
    add_index :footnotes, %i[footnote_type_id footnote_id]
    # Covers the time_machine validity date filter.
    add_index :footnotes, %i[validity_start_date validity_end_date]

    # --- footnote_description_periods ----------------------------------------

    drop_view :footnote_description_periods

    create_view :footnote_description_periods, <<~SQL, materialized: true
      SELECT footnote_description_period_sid,
             footnote_type_id,
             footnote_id,
             validity_start_date,
             validity_end_date,
             "national",
             oid,
             operation,
             operation_date,
             filename
      FROM uk.footnote_description_periods_oplog footnote_description_periods1
      WHERE oid IN (
        SELECT max(footnote_description_periods2.oid)
        FROM uk.footnote_description_periods_oplog footnote_description_periods2
        WHERE footnote_description_periods1.footnote_id::text = footnote_description_periods2.footnote_id::text
          AND footnote_description_periods1.footnote_type_id::text = footnote_description_periods2.footnote_type_id::text
          AND footnote_description_periods1.footnote_description_period_sid = footnote_description_periods2.footnote_description_period_sid
      )
      AND operation::text <> 'D'
    SQL

    add_index :footnote_description_periods, :oid, unique: true
    # Covers (footnote_type_id, footnote_id) IN (...) + validity_start_date <= ?
    # in a single index range scan.
    add_index :footnote_description_periods, %i[footnote_type_id footnote_id validity_start_date]

    # --- footnote_descriptions -----------------------------------------------

    drop_view :footnote_descriptions

    create_view :footnote_descriptions, <<~SQL, materialized: true
      SELECT footnote_description_period_sid,
             footnote_type_id,
             footnote_id,
             language_id,
             description,
             "national",
             oid,
             operation,
             operation_date,
             filename
      FROM uk.footnote_descriptions_oplog footnote_descriptions1
      WHERE oid IN (
        SELECT max(footnote_descriptions2.oid)
        FROM uk.footnote_descriptions_oplog footnote_descriptions2
        WHERE footnote_descriptions1.footnote_description_period_sid = footnote_descriptions2.footnote_description_period_sid
          AND footnote_descriptions1.footnote_id::text = footnote_descriptions2.footnote_id::text
          AND footnote_descriptions1.footnote_type_id::text = footnote_descriptions2.footnote_type_id::text
      )
      AND operation::text <> 'D'
    SQL

    add_index :footnote_descriptions, :oid, unique: true
    # Covers the three-column join key used by the many_to_many association.
    add_index :footnote_descriptions, %i[footnote_description_period_sid footnote_type_id footnote_id]

    # --- measure_conditions --------------------------------------------------

    drop_view :measure_conditions

    create_view :measure_conditions, <<~SQL, materialized: true
      SELECT measure_condition_sid,
             measure_sid,
             condition_code,
             component_sequence_number,
             condition_duty_amount,
             condition_monetary_unit_code,
             condition_measurement_unit_code,
             condition_measurement_unit_qualifier_code,
             action_code,
             certificate_type_code,
             certificate_code,
             oid,
             operation,
             operation_date,
             filename
      FROM uk.measure_conditions_oplog measure_conditions1
      WHERE oid IN (
        SELECT max(measure_conditions2.oid)
        FROM uk.measure_conditions_oplog measure_conditions2
        WHERE measure_conditions1.measure_condition_sid = measure_conditions2.measure_condition_sid
      )
      AND operation::text <> 'D'
    SQL

    add_index :measure_conditions, :oid, unique: true
    # Covers the primary eager-load pattern: measure_sid IN (...).
    add_index :measure_conditions, :measure_sid
    add_index :measure_conditions, :measure_condition_sid

    # --- measure_components --------------------------------------------------
    # Drop the dependent view first; recreated at the end of this migration.

    drop_view :simplified_procedural_code_measures
    drop_view :measure_components

    create_view :measure_components, <<~SQL, materialized: true
      SELECT measure_sid,
             duty_expression_id,
             duty_amount,
             monetary_unit_code,
             measurement_unit_code,
             measurement_unit_qualifier_code,
             oid,
             operation,
             operation_date,
             filename
      FROM uk.measure_components_oplog measure_components1
      WHERE oid IN (
        SELECT max(measure_components2.oid)
        FROM uk.measure_components_oplog measure_components2
        WHERE measure_components1.measure_sid = measure_components2.measure_sid
          AND measure_components1.duty_expression_id::text = measure_components2.duty_expression_id::text
      )
      AND operation::text <> 'D'
    SQL

    add_index :measure_components, :oid, unique: true
    # Covers measure_sid IN (...) eager loads.
    add_index :measure_components, :measure_sid

    # Recreate the dependent view now that measure_components is materialized.
    create_or_replace_view :simplified_procedural_code_measures, <<~SQL
      SELECT simplified_procedural_codes.simplified_procedural_code,
             measures.validity_start_date,
             measures.validity_end_date,
             string_agg(DISTINCT simplified_procedural_codes.goods_nomenclature_item_id, ', ') AS goods_nomenclature_item_ids,
             max(measure_components.duty_amount) AS duty_amount,
             max(measure_components.monetary_unit_code::text) AS monetary_unit_code,
             max(measure_components.measurement_unit_code::text) AS measurement_unit_code,
             max(measure_components.measurement_unit_qualifier_code::text) AS measurement_unit_qualifier_code,
             max(simplified_procedural_codes.goods_nomenclature_label) AS goods_nomenclature_label
      FROM uk.measures
        JOIN uk.measure_components ON measures.measure_sid = measure_components.measure_sid
        RIGHT JOIN uk.simplified_procedural_codes
          ON measures.goods_nomenclature_item_id::text = simplified_procedural_codes.goods_nomenclature_item_id
         AND measures.measure_type_id::text = '488'
         AND measures.validity_end_date > '2021-01-01'
         AND measures.geographical_area_id::text = '1011'
      GROUP BY simplified_procedural_codes.simplified_procedural_code,
               measures.validity_start_date,
               measures.validity_end_date
    SQL
  end

  down do
    drop_view :simplified_procedural_code_measures

    drop_view(:measure_components, materialized: true) if MeasureComponent.actually_materialized?
    drop_view(:measure_conditions, materialized: true) if MeasureCondition.actually_materialized?
    drop_view(:footnote_descriptions, materialized: true) if FootnoteDescription.actually_materialized?
    drop_view(:footnote_description_periods, materialized: true) if FootnoteDescriptionPeriod.actually_materialized?
    drop_view(:footnotes, materialized: true) if Footnote.actually_materialized?

    create_or_replace_view :footnotes, <<~SQL
      SELECT footnote_id,
             footnote_type_id,
             validity_start_date,
             validity_end_date,
             "national",
             oid,
             operation,
             operation_date,
             filename
      FROM uk.footnotes_oplog footnotes1
      WHERE oid IN (
        SELECT max(footnotes2.oid)
        FROM uk.footnotes_oplog footnotes2
        WHERE footnotes1.footnote_type_id::text = footnotes2.footnote_type_id::text
          AND footnotes1.footnote_id::text = footnotes2.footnote_id::text
      )
      AND operation::text <> 'D'
    SQL

    create_or_replace_view :footnote_description_periods, <<~SQL
      SELECT footnote_description_period_sid,
             footnote_type_id,
             footnote_id,
             validity_start_date,
             validity_end_date,
             "national",
             oid,
             operation,
             operation_date,
             filename
      FROM uk.footnote_description_periods_oplog footnote_description_periods1
      WHERE oid IN (
        SELECT max(footnote_description_periods2.oid)
        FROM uk.footnote_description_periods_oplog footnote_description_periods2
        WHERE footnote_description_periods1.footnote_id::text = footnote_description_periods2.footnote_id::text
          AND footnote_description_periods1.footnote_type_id::text = footnote_description_periods2.footnote_type_id::text
          AND footnote_description_periods1.footnote_description_period_sid = footnote_description_periods2.footnote_description_period_sid
      )
      AND operation::text <> 'D'
    SQL

    create_or_replace_view :footnote_descriptions, <<~SQL
      SELECT footnote_description_period_sid,
             footnote_type_id,
             footnote_id,
             language_id,
             description,
             "national",
             oid,
             operation,
             operation_date,
             filename
      FROM uk.footnote_descriptions_oplog footnote_descriptions1
      WHERE oid IN (
        SELECT max(footnote_descriptions2.oid)
        FROM uk.footnote_descriptions_oplog footnote_descriptions2
        WHERE footnote_descriptions1.footnote_description_period_sid = footnote_descriptions2.footnote_description_period_sid
          AND footnote_descriptions1.footnote_id::text = footnote_descriptions2.footnote_id::text
          AND footnote_descriptions1.footnote_type_id::text = footnote_descriptions2.footnote_type_id::text
      )
      AND operation::text <> 'D'
    SQL

    create_or_replace_view :measure_conditions, <<~SQL
      SELECT measure_condition_sid,
             measure_sid,
             condition_code,
             component_sequence_number,
             condition_duty_amount,
             condition_monetary_unit_code,
             condition_measurement_unit_code,
             condition_measurement_unit_qualifier_code,
             action_code,
             certificate_type_code,
             certificate_code,
             oid,
             operation,
             operation_date,
             filename
      FROM uk.measure_conditions_oplog measure_conditions1
      WHERE oid IN (
        SELECT max(measure_conditions2.oid)
        FROM uk.measure_conditions_oplog measure_conditions2
        WHERE measure_conditions1.measure_condition_sid = measure_conditions2.measure_condition_sid
      )
      AND operation::text <> 'D'
    SQL

    create_or_replace_view :measure_components, <<~SQL
      SELECT measure_sid,
             duty_expression_id,
             duty_amount,
             monetary_unit_code,
             measurement_unit_code,
             measurement_unit_qualifier_code,
             oid,
             operation,
             operation_date,
             filename
      FROM uk.measure_components_oplog measure_components1
      WHERE oid IN (
        SELECT max(measure_components2.oid)
        FROM uk.measure_components_oplog measure_components2
        WHERE measure_components1.measure_sid = measure_components2.measure_sid
          AND measure_components1.duty_expression_id::text = measure_components2.duty_expression_id::text
      )
      AND operation::text <> 'D'
    SQL

    create_or_replace_view :simplified_procedural_code_measures, <<~SQL
      SELECT simplified_procedural_codes.simplified_procedural_code,
             measures.validity_start_date,
             measures.validity_end_date,
             string_agg(DISTINCT simplified_procedural_codes.goods_nomenclature_item_id, ', ') AS goods_nomenclature_item_ids,
             max(measure_components.duty_amount) AS duty_amount,
             max(measure_components.monetary_unit_code::text) AS monetary_unit_code,
             max(measure_components.measurement_unit_code::text) AS measurement_unit_code,
             max(measure_components.measurement_unit_qualifier_code::text) AS measurement_unit_qualifier_code,
             max(simplified_procedural_codes.goods_nomenclature_label) AS goods_nomenclature_label
      FROM uk.measures
        JOIN uk.measure_components ON measures.measure_sid = measure_components.measure_sid
        RIGHT JOIN uk.simplified_procedural_codes
          ON measures.goods_nomenclature_item_id::text = simplified_procedural_codes.goods_nomenclature_item_id
         AND measures.measure_type_id::text = '488'
         AND measures.validity_end_date > '2021-01-01'
         AND measures.geographical_area_id::text = '1011'
      GROUP BY simplified_procedural_codes.simplified_procedural_code,
               measures.validity_start_date,
               measures.validity_end_date
    SQL
  end
end
