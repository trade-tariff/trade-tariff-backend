# frozen_string_literal: true

Sequel.migration do
  up do
    drop_view :bad_quota_associations
    drop_view :quota_balance_events
    drop_view :quota_critical_events
    drop_view :quota_definitions
    drop_view :quota_exhaustion_events
    drop_view :quota_reopening_events
    drop_view :quota_unblocking_events
    drop_view :quota_unsuspension_events

    create_view :quota_balance_events, <<~EOVIEW, materialized: true
      SELECT quota_balance_events1.quota_definition_sid,
        quota_balance_events1.occurrence_timestamp,
        quota_balance_events1.last_import_date_in_allocation,
        quota_balance_events1.old_balance,
        quota_balance_events1.new_balance,
        quota_balance_events1.imported_amount,
        quota_balance_events1.oid,
        quota_balance_events1.operation,
        quota_balance_events1.operation_date,
        quota_balance_events1.filename
      FROM quota_balance_events_oplog quota_balance_events1
      WHERE (quota_balance_events1.oid IN ( SELECT max(quota_balance_events2.oid) AS max
              FROM quota_balance_events_oplog quota_balance_events2
              WHERE quota_balance_events1.quota_definition_sid = quota_balance_events2.quota_definition_sid AND quota_balance_events1.occurrence_timestamp = quota_balance_events2.occurrence_timestamp)) AND quota_balance_events1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :quota_critical_events, <<~EOVIEW, materialized: true
    SELECT quota_critical_events1.quota_definition_sid,
      quota_critical_events1.occurrence_timestamp,
      quota_critical_events1.critical_state,
      quota_critical_events1.critical_state_change_date,
      quota_critical_events1.oid,
      quota_critical_events1.operation,
      quota_critical_events1.operation_date,
      quota_critical_events1.filename
    FROM quota_critical_events_oplog quota_critical_events1
    WHERE (quota_critical_events1.oid IN ( SELECT max(quota_critical_events2.oid) AS max
            FROM quota_critical_events_oplog quota_critical_events2
            WHERE quota_critical_events1.quota_definition_sid = quota_critical_events2.quota_definition_sid AND quota_critical_events1.occurrence_timestamp = quota_critical_events2.occurrence_timestamp)) AND quota_critical_events1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :quota_definitions, <<~EOVIEW, materialized: true
    SELECT quota_definitions1.quota_definition_sid,
        quota_definitions1.quota_order_number_id,
        quota_definitions1.validity_start_date,
        quota_definitions1.validity_end_date,
        quota_definitions1.quota_order_number_sid,
        quota_definitions1.volume,
        quota_definitions1.initial_volume,
        quota_definitions1.measurement_unit_code,
        quota_definitions1.maximum_precision,
        quota_definitions1.critical_state,
        quota_definitions1.critical_threshold,
        quota_definitions1.monetary_unit_code,
        quota_definitions1.measurement_unit_qualifier_code,
        quota_definitions1.description,
        quota_definitions1.oid,
        quota_definitions1.operation,
        quota_definitions1.operation_date,
        quota_definitions1.filename
      FROM quota_definitions_oplog quota_definitions1
      WHERE (quota_definitions1.oid IN ( SELECT max(quota_definitions2.oid) AS max
              FROM quota_definitions_oplog quota_definitions2
              WHERE quota_definitions1.quota_definition_sid = quota_definitions2.quota_definition_sid)) AND quota_definitions1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :quota_exhaustion_events, <<~EOVIEW, materialized: true
      SELECT quota_exhaustion_events1.quota_definition_sid,
        quota_exhaustion_events1.occurrence_timestamp,
        quota_exhaustion_events1.exhaustion_date,
        quota_exhaustion_events1.oid,
        quota_exhaustion_events1.operation,
        quota_exhaustion_events1.operation_date,
        quota_exhaustion_events1.filename
      FROM quota_exhaustion_events_oplog quota_exhaustion_events1
      WHERE (quota_exhaustion_events1.oid IN ( SELECT max(quota_exhaustion_events2.oid) AS max
              FROM quota_exhaustion_events_oplog quota_exhaustion_events2
              WHERE quota_exhaustion_events1.quota_definition_sid = quota_exhaustion_events2.quota_definition_sid AND quota_exhaustion_events1.occurrence_timestamp = quota_exhaustion_events2.occurrence_timestamp)) AND quota_exhaustion_events1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :quota_reopening_events, <<~EOVIEW, materialized: true
    SELECT quota_reopening_events1.quota_definition_sid,
        quota_reopening_events1.occurrence_timestamp,
        quota_reopening_events1.reopening_date,
        quota_reopening_events1.oid,
        quota_reopening_events1.operation,
        quota_reopening_events1.operation_date,
        quota_reopening_events1.filename
      FROM quota_reopening_events_oplog quota_reopening_events1
      WHERE (quota_reopening_events1.oid IN ( SELECT max(quota_reopening_events2.oid) AS max
              FROM quota_reopening_events_oplog quota_reopening_events2
              WHERE quota_reopening_events1.quota_definition_sid = quota_reopening_events2.quota_definition_sid AND quota_reopening_events1.occurrence_timestamp = quota_reopening_events2.occurrence_timestamp)) AND quota_reopening_events1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :quota_unblocking_events, <<~EOVIEW, materialized: true
    SELECT quota_unblocking_events1.quota_definition_sid,
      quota_unblocking_events1.occurrence_timestamp,
      quota_unblocking_events1.unblocking_date,
      quota_unblocking_events1.oid,
      quota_unblocking_events1.operation,
      quota_unblocking_events1.operation_date,
      quota_unblocking_events1.filename
    FROM quota_unblocking_events_oplog quota_unblocking_events1
    WHERE (quota_unblocking_events1.oid IN ( SELECT max(quota_unblocking_events2.oid) AS max
            FROM quota_unblocking_events_oplog quota_unblocking_events2
            WHERE quota_unblocking_events1.quota_definition_sid = quota_unblocking_events2.quota_definition_sid)) AND quota_unblocking_events1.operation::text <> 'D'::text
        WITH DATA
    EOVIEW

    create_view :quota_unsuspension_events, <<~EOVIEW, materialized: true
    SELECT quota_unsuspension_events1.quota_definition_sid,
      quota_unsuspension_events1.occurrence_timestamp,
      quota_unsuspension_events1.unsuspension_date,
      quota_unsuspension_events1.oid,
      quota_unsuspension_events1.operation,
      quota_unsuspension_events1.operation_date,
      quota_unsuspension_events1.filename
    FROM quota_unsuspension_events_oplog quota_unsuspension_events1
    WHERE (quota_unsuspension_events1.oid IN ( SELECT max(quota_unsuspension_events2.oid) AS max
            FROM quota_unsuspension_events_oplog quota_unsuspension_events2
            WHERE quota_unsuspension_events1.quota_definition_sid = quota_unsuspension_events2.quota_definition_sid AND quota_unsuspension_events1.occurrence_timestamp = quota_unsuspension_events2.occurrence_timestamp)) AND quota_unsuspension_events1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :bad_quota_associations, <<~EOVIEW, materialized: true
    SELECT qd_main.quota_order_number_id AS main_quota_order_number_id,
      qd_main.validity_start_date,
      qd_main.validity_end_date,
      qono_main.geographical_area_id AS main_origin,
      qd_sub.quota_order_number_id AS sub_quota_order_number_id,
      qono_sub.geographical_area_id AS sub_origin,
          CASE
              WHEN qa.main_quota_definition_sid = qa.sub_quota_definition_sid THEN 'self'::text
              ELSE 'other'::text
          END AS linkage,
      qa.relation_type,
      qa.coefficient
    FROM quota_associations qa
     JOIN quota_definitions qd_main ON qa.main_quota_definition_sid = qd_main.quota_definition_sid
     JOIN quota_definitions qd_sub ON qa.sub_quota_definition_sid = qd_sub.quota_definition_sid
     JOIN quota_order_numbers qon_main ON qon_main.quota_order_number_sid = qd_main.quota_order_number_sid
     JOIN quota_order_numbers qon_sub ON qon_sub.quota_order_number_sid = qd_sub.quota_order_number_sid
     JOIN quota_order_number_origins qono_main ON qon_main.quota_order_number_sid = qono_main.quota_order_number_sid
     JOIN quota_order_number_origins qono_sub ON qon_sub.quota_order_number_sid = qono_sub.quota_order_number_sid
    WHERE qd_main.validity_start_date >= '2021-01-01 00:00:00'::timestamp without time zone
    ORDER BY qd_main.quota_order_number_id, qd_sub.quota_order_number_id, qd_main.validity_start_date
      WITH DATA
    EOVIEW

    alter_table :quota_balance_events do
      add_index :oid, unique: true
      add_index :operation_date
      add_index Sequel.lit('quota_definition_sid, occurrence_timestamp, oid DESC')
    end

    alter_table :quota_critical_events do
      add_index :oid, unique: true
      add_index :operation_date
      add_index [:quota_definition_sid, :occurrence_timestamp]
    end

    alter_table :quota_definitions do
      add_index :oid, unique: true
      add_index :operation_date
      add_index :quota_order_number_id
      add_index :measurement_unit_code
      add_index :monetary_unit_code
      add_index :measurement_unit_qualifier_code
      add_index Sequel.lit('quota_definition_sid, oid DESC')
    end

    alter_table :quota_exhaustion_events do
      add_index :oid, unique: true
      add_index :operation_date
      add_index [:quota_definition_sid, :occurrence_timestamp]
    end

    alter_table :quota_reopening_events do
      add_index :oid, unique: true
      add_index :operation_date
      add_index [:quota_definition_sid, :occurrence_timestamp]
    end

    alter_table :quota_unblocking_events do
      add_index :oid, unique: true
      add_index :operation_date
      add_index [:quota_definition_sid, :occurrence_timestamp]
    end

    alter_table :quota_unsuspension_events do
      add_index :oid, unique: true
      add_index :operation_date
      add_index [:quota_definition_sid, :occurrence_timestamp]
    end
  end

  down do
    drop_view :bad_quota_associations, materialized: true
    drop_view :quota_balance_events, materialized: true
    drop_view :quota_critical_events, materialized: true
    drop_view :quota_definitions, materialized: true
    drop_view :quota_exhaustion_events, materialized: true
    drop_view :quota_reopening_events, materialized: true
    drop_view :quota_unblocking_events, materialized: true
    drop_view :quota_unsuspension_events, materialized: true

    create_view :quota_balance_events, <<~EOVIEW
      SELECT quota_balance_events1.quota_definition_sid,
        quota_balance_events1.occurrence_timestamp,
        quota_balance_events1.last_import_date_in_allocation,
        quota_balance_events1.old_balance,
        quota_balance_events1.new_balance,
        quota_balance_events1.imported_amount,
        quota_balance_events1.oid,
        quota_balance_events1.operation,
        quota_balance_events1.operation_date,
        quota_balance_events1.filename
      FROM quota_balance_events_oplog quota_balance_events1
      WHERE (quota_balance_events1.oid IN ( SELECT max(quota_balance_events2.oid) AS max
              FROM quota_balance_events_oplog quota_balance_events2
              WHERE quota_balance_events1.quota_definition_sid = quota_balance_events2.quota_definition_sid AND quota_balance_events1.occurrence_timestamp = quota_balance_events2.occurrence_timestamp)) AND quota_balance_events1.operation::text <> 'D'::text;
    EOVIEW

    create_view :quota_critical_events, <<~EOVIEW
      SELECT quota_critical_events1.quota_definition_sid,
          quota_critical_events1.occurrence_timestamp,
          quota_critical_events1.critical_state,
          quota_critical_events1.critical_state_change_date,
          quota_critical_events1.oid,
          quota_critical_events1.operation,
          quota_critical_events1.operation_date,
          quota_critical_events1.filename
        FROM quota_critical_events_oplog quota_critical_events1
        WHERE (quota_critical_events1.oid IN ( SELECT max(quota_critical_events2.oid) AS max
                FROM quota_critical_events_oplog quota_critical_events2
                WHERE quota_critical_events1.quota_definition_sid = quota_critical_events2.quota_definition_sid AND quota_critical_events1.occurrence_timestamp = quota_critical_events2.occurrence_timestamp)) AND quota_critical_events1.operation::text <> 'D'::text
    EOVIEW

    create_view :quota_definitions, <<~EOVIEW
      SELECT quota_definitions1.quota_definition_sid,
        quota_definitions1.quota_order_number_id,
        quota_definitions1.validity_start_date,
        quota_definitions1.validity_end_date,
        quota_definitions1.quota_order_number_sid,
        quota_definitions1.volume,
        quota_definitions1.initial_volume,
        quota_definitions1.measurement_unit_code,
        quota_definitions1.maximum_precision,
        quota_definitions1.critical_state,
        quota_definitions1.critical_threshold,
        quota_definitions1.monetary_unit_code,
        quota_definitions1.measurement_unit_qualifier_code,
        quota_definitions1.description,
        quota_definitions1.oid,
        quota_definitions1.operation,
        quota_definitions1.operation_date,
        quota_definitions1.filename
      FROM quota_definitions_oplog quota_definitions1
      WHERE (quota_definitions1.oid IN ( SELECT max(quota_definitions2.oid) AS max
              FROM quota_definitions_oplog quota_definitions2
              WHERE quota_definitions1.quota_definition_sid = quota_definitions2.quota_definition_sid)) AND quota_definitions1.operation::text <> 'D'::text
    EOVIEW

    create_view :quota_exhaustion_events, <<~EOVIEW
    SELECT quota_exhaustion_events1.quota_definition_sid,
      quota_exhaustion_events1.occurrence_timestamp,
      quota_exhaustion_events1.exhaustion_date,
      quota_exhaustion_events1.oid,
      quota_exhaustion_events1.operation,
      quota_exhaustion_events1.operation_date,
      quota_exhaustion_events1.filename
    FROM quota_exhaustion_events_oplog quota_exhaustion_events1
    WHERE (quota_exhaustion_events1.oid IN ( SELECT max(quota_exhaustion_events2.oid) AS max
            FROM quota_exhaustion_events_oplog quota_exhaustion_events2
            WHERE quota_exhaustion_events1.quota_definition_sid = quota_exhaustion_events2.quota_definition_sid AND quota_exhaustion_events1.occurrence_timestamp = quota_exhaustion_events2.occurrence_timestamp)) AND quota_exhaustion_events1.operation::text <> 'D'::text
    EOVIEW

    create_view :quota_reopening_events, <<~EOVIEW
    SELECT quota_reopening_events1.quota_definition_sid,
      quota_reopening_events1.occurrence_timestamp,
      quota_reopening_events1.reopening_date,
      quota_reopening_events1.oid,
      quota_reopening_events1.operation,
      quota_reopening_events1.operation_date,
      quota_reopening_events1.filename
    FROM quota_reopening_events_oplog quota_reopening_events1
    WHERE (quota_reopening_events1.oid IN ( SELECT max(quota_reopening_events2.oid) AS max
            FROM quota_reopening_events_oplog quota_reopening_events2
            WHERE quota_reopening_events1.quota_definition_sid = quota_reopening_events2.quota_definition_sid AND quota_reopening_events1.occurrence_timestamp = quota_reopening_events2.occurrence_timestamp)) AND quota_reopening_events1.operation::text <> 'D'::text
    EOVIEW

    create_view :quota_unblocking_events, <<~EOVIEW
    SELECT quota_unblocking_events1.quota_definition_sid,
      quota_unblocking_events1.occurrence_timestamp,
      quota_unblocking_events1.unblocking_date,
      quota_unblocking_events1.oid,
      quota_unblocking_events1.operation,
      quota_unblocking_events1.operation_date,
      quota_unblocking_events1.filename
    FROM quota_unblocking_events_oplog quota_unblocking_events1
    WHERE (quota_unblocking_events1.oid IN ( SELECT max(quota_unblocking_events2.oid) AS max
            FROM quota_unblocking_events_oplog quota_unblocking_events2
            WHERE quota_unblocking_events1.quota_definition_sid = quota_unblocking_events2.quota_definition_sid)) AND quota_unblocking_events1.operation::text <> 'D'::text
    EOVIEW

    create_view :quota_unsuspension_events, <<~EOVIEW
    SELECT quota_unsuspension_events1.quota_definition_sid,
      quota_unsuspension_events1.occurrence_timestamp,
      quota_unsuspension_events1.unsuspension_date,
      quota_unsuspension_events1.oid,
      quota_unsuspension_events1.operation,
      quota_unsuspension_events1.operation_date,
      quota_unsuspension_events1.filename
    FROM quota_unsuspension_events_oplog quota_unsuspension_events1
    WHERE (quota_unsuspension_events1.oid IN ( SELECT max(quota_unsuspension_events2.oid) AS max
            FROM quota_unsuspension_events_oplog quota_unsuspension_events2
            WHERE quota_unsuspension_events1.quota_definition_sid = quota_unsuspension_events2.quota_definition_sid AND quota_unsuspension_events1.occurrence_timestamp = quota_unsuspension_events2.occurrence_timestamp)) AND quota_unsuspension_events1.operation::text <> 'D'::text
    EOVIEW

    create_view :bad_quota_associations, <<~EOVIEW
    SELECT qd_main.quota_order_number_id AS main_quota_order_number_id,
      qd_main.validity_start_date,
      qd_main.validity_end_date,
      qono_main.geographical_area_id AS main_origin,
      qd_sub.quota_order_number_id AS sub_quota_order_number_id,
      qono_sub.geographical_area_id AS sub_origin,
          CASE
              WHEN qa.main_quota_definition_sid = qa.sub_quota_definition_sid THEN 'self'::text
              ELSE 'other'::text
          END AS linkage,
      qa.relation_type,
      qa.coefficient
    FROM quota_associations qa
     JOIN quota_definitions qd_main ON qa.main_quota_definition_sid = qd_main.quota_definition_sid
     JOIN quota_definitions qd_sub ON qa.sub_quota_definition_sid = qd_sub.quota_definition_sid
     JOIN quota_order_numbers qon_main ON qon_main.quota_order_number_sid = qd_main.quota_order_number_sid
     JOIN quota_order_numbers qon_sub ON qon_sub.quota_order_number_sid = qd_sub.quota_order_number_sid
     JOIN quota_order_number_origins qono_main ON qon_main.quota_order_number_sid = qono_main.quota_order_number_sid
     JOIN quota_order_number_origins qono_sub ON qon_sub.quota_order_number_sid = qono_sub.quota_order_number_sid
    WHERE qd_main.validity_start_date >= '2021-01-01 00:00:00'::timestamp without time zone
    ORDER BY qd_main.quota_order_number_id, qd_sub.quota_order_number_id, qd_main.validity_start_date
    EOVIEW
  end
end
