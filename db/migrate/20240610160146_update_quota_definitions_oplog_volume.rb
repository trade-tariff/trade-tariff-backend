Sequel.migration do
  up do
    run 'DROP VIEW xi.bad_quota_associations'
    run 'DROP VIEW xi.quota_definitions;'

    alter_table :quota_definitions_oplog do
      set_column_type :volume, BigDecimal, size: [15, 3]
      set_column_type :initial_volume, BigDecimal, size: [15, 3]
    end

    run %{
          CREATE VIEW xi.quota_definitions AS
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
              FROM xi.quota_definitions_oplog quota_definitions1
              WHERE ((quota_definitions1.oid IN ( SELECT max(quota_definitions2.oid) AS max
                      FROM xi.quota_definitions_oplog quota_definitions2
                      WHERE (quota_definitions1.quota_definition_sid = quota_definitions2.quota_definition_sid))) AND ((quota_definitions1.operation)::text <> 'D'::text));

          CREATE VIEW xi.bad_quota_associations AS
            SELECT qd_main.quota_order_number_id AS main_quota_order_number_id,
              qd_main.validity_start_date,
              qd_main.validity_end_date,
              qono_main.geographical_area_id AS main_origin,
              qd_sub.quota_order_number_id AS sub_quota_order_number_id,
              qono_sub.geographical_area_id AS sub_origin,
                  CASE
                      WHEN (qa.main_quota_definition_sid = qa.sub_quota_definition_sid) THEN 'self'::text
                      ELSE 'other'::text
                  END AS linkage,
              qa.relation_type,
              qa.coefficient
              FROM ((((((xi.quota_associations qa
                JOIN xi.quota_definitions qd_main ON ((qa.main_quota_definition_sid = qd_main.quota_definition_sid)))
                JOIN xi.quota_definitions qd_sub ON ((qa.sub_quota_definition_sid = qd_sub.quota_definition_sid)))
                JOIN xi.quota_order_numbers qon_main ON ((qon_main.quota_order_number_sid = qd_main.quota_order_number_sid)))
                JOIN xi.quota_order_numbers qon_sub ON ((qon_sub.quota_order_number_sid = qd_sub.quota_order_number_sid)))
                JOIN xi.quota_order_number_origins qono_main ON ((qon_main.quota_order_number_sid = qono_main.quota_order_number_sid)))
                JOIN xi.quota_order_number_origins qono_sub ON ((qon_sub.quota_order_number_sid = qono_sub.quota_order_number_sid)))
              WHERE (qd_main.validity_start_date >= '2021-01-01 00:00:00'::timestamp without time zone)
              ORDER BY qd_main.quota_order_number_id, qd_sub.quota_order_number_id, qd_main.validity_start_date;
      }
  end

  down do
    run 'DROP VIEW xi.bad_quota_associations'
    run 'DROP VIEW xi.quota_definitions;'

    alter_table :quota_definitions_oplog do
      set_column_type :volume, BigDecimal, size: [12, 2]
      set_column_type :initial_volume, BigDecimal, size: [12, 2]
    end

    run %{
          CREATE VIEW xi.quota_definitions AS
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
              FROM xi.quota_definitions_oplog quota_definitions1
              WHERE ((quota_definitions1.oid IN ( SELECT max(quota_definitions2.oid) AS max
                      FROM xi.quota_definitions_oplog quota_definitions2
                      WHERE (quota_definitions1.quota_definition_sid = quota_definitions2.quota_definition_sid))) AND ((quota_definitions1.operation)::text <> 'D'::text));

          CREATE VIEW xi.bad_quota_associations AS
            SELECT qd_main.quota_order_number_id AS main_quota_order_number_id,
              qd_main.validity_start_date,
              qd_main.validity_end_date,
              qono_main.geographical_area_id AS main_origin,
              qd_sub.quota_order_number_id AS sub_quota_order_number_id,
              qono_sub.geographical_area_id AS sub_origin,
                  CASE
                      WHEN (qa.main_quota_definition_sid = qa.sub_quota_definition_sid) THEN 'self'::text
                      ELSE 'other'::text
                  END AS linkage,
              qa.relation_type,
              qa.coefficient
              FROM ((((((xi.quota_associations qa
                JOIN xi.quota_definitions qd_main ON ((qa.main_quota_definition_sid = qd_main.quota_definition_sid)))
                JOIN xi.quota_definitions qd_sub ON ((qa.sub_quota_definition_sid = qd_sub.quota_definition_sid)))
                JOIN xi.quota_order_numbers qon_main ON ((qon_main.quota_order_number_sid = qd_main.quota_order_number_sid)))
                JOIN xi.quota_order_numbers qon_sub ON ((qon_sub.quota_order_number_sid = qd_sub.quota_order_number_sid)))
                JOIN xi.quota_order_number_origins qono_main ON ((qon_main.quota_order_number_sid = qono_main.quota_order_number_sid)))
                JOIN xi.quota_order_number_origins qono_sub ON ((qon_sub.quota_order_number_sid = qono_sub.quota_order_number_sid)))
              WHERE (qd_main.validity_start_date >= '2021-01-01 00:00:00'::timestamp without time zone)
              ORDER BY qd_main.quota_order_number_id, qd_sub.quota_order_number_id, qd_main.validity_start_date;
      }
  end
end
