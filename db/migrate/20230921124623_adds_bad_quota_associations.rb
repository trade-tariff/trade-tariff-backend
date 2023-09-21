Sequel.migration do
  up do
    run %Q{
      CREATE VIEW bad_quota_associations AS
        SELECT
            qd_main.quota_order_number_id AS main_quota_order_number_id,
            qd_main.validity_start_date,
            qd_main.validity_end_date,
            qono_main.geographical_area_id AS main_origin,
            qd_sub.quota_order_number_id AS sub_quota_order_number_id,
            qono_sub.geographical_area_id AS sub_origin,
            CASE
                WHEN qa.main_quota_definition_sid = qa.sub_quota_definition_sid THEN 'self'
                ELSE 'other'
            END AS linkage,
            qa.relation_type,
            qa.coefficient
        FROM
            quota_associations AS qa
        JOIN
            quota_definitions AS qd_main ON qa.main_quota_definition_sid = qd_main.quota_definition_sid
        JOIN
            quota_definitions AS qd_sub ON qa.sub_quota_definition_sid = qd_sub.quota_definition_sid
        JOIN
            quota_order_numbers AS qon_main ON qon_main.quota_order_number_sid = qd_main.quota_order_number_sid
        JOIN
            quota_order_numbers AS qon_sub ON qon_sub.quota_order_number_sid = qd_sub.quota_order_number_sid
        JOIN
            quota_order_number_origins AS qono_main ON qon_main.quota_order_number_sid = qono_main.quota_order_number_sid
        JOIN
            quota_order_number_origins AS qono_sub ON qon_sub.quota_order_number_sid = qono_sub.quota_order_number_sid
        WHERE
            qd_main.validity_start_date >= '2021-01-01 00:00:00'::timestamp without time zone
        ORDER BY
            qd_main.quota_order_number_id,
            qd_sub.quota_order_number_id,
            qd_main.validity_start_date;
    }
  end

  down do
    drop_view :bad_quota_associations
  end
end
