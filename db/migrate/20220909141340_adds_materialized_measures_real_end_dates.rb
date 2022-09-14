# frozen_string_literal: true

Sequel.migration do
  up do
    run %{
      CREATE MATERIALIZED VIEW measure_real_end_dates AS
      SELECT
          "t1"."measure_sid",
          "t1"."measure_type_id",
          "t1"."geographical_area_id",
          "t1"."goods_nomenclature_item_id",
          "t1"."effective_end_date",
          "t1"."validity_start_date",
          "t1"."validity_end_date",
          "t1"."measure_generating_regulation_role",
          "t1"."measure_generating_regulation_id",
          "t1"."justification_regulation_role",
          "t1"."justification_regulation_id",
          "t1"."stopped_flag",
          "t1"."geographical_area_sid",
          "t1"."goods_nomenclature_sid",
          "t1"."ordernumber",
          "t1"."additional_code_type_id",
          "t1"."additional_code_id",
          "t1"."additional_code_sid",
          "t1"."reduction_indicator",
          "t1"."export_refund_nomenclature_sid",
          "t1"."national",
          "t1"."tariff_measure_number",
          "t1"."invalidated_by",
          "t1"."invalidated_at",
          "t1"."oid",
          "t1"."operation",
          "t1"."operation_date",
          "t1"."filename"
      FROM
          "measures"
          INNER JOIN (
              SELECT
                  *
              FROM (
                  SELECT
                      *
                  FROM (
                      SELECT
                          "measures".*,
                          (
                              CASE WHEN ("measures"."validity_end_date" IS NOT NULL) THEN
                                  measures.validity_end_date
                              WHEN ("base_regulations"."effective_end_date" IS NOT NULL) THEN
                                  base_regulations.effective_end_date
                              ELSE
                                  base_regulations.validity_end_date
                              END) AS "effective_end_date"
                      FROM
                          "measures"
                      INNER JOIN "base_regulations" ON ("base_regulations"."base_regulation_id" = "measures"."measure_generating_regulation_id")
                  WHERE (("measure_generating_regulation_role" IN (1, 2, 3)))
              ORDER BY
                  "measures"."measure_generating_regulation_id" DESC,
                  "measures"."measure_generating_regulation_role" DESC,
                  "measures"."measure_type_id" DESC,
                  "measures"."goods_nomenclature_sid" DESC,
                  "measures"."geographical_area_id" DESC,
                  "measures"."geographical_area_sid" DESC,
                  "measures"."additional_code_type_id" DESC,
                  "measures"."additional_code_id" DESC,
                  "measures"."ordernumber" DESC,
                  "measures"."validity_start_date" DESC) AS "t1"
          UNION (
              SELECT
                  *
              FROM (
                  SELECT
                      "measures".*,
                      (
                          CASE WHEN ("measures"."validity_end_date" IS NOT NULL) THEN
                              measures.validity_end_date
                          WHEN ("modification_regulations"."effective_end_date" IS NOT NULL) THEN
                              modification_regulations.effective_end_date
                          ELSE
                              modification_regulations.validity_end_date
                          END) AS "effective_end_date"
                  FROM
                      "measures"
                      INNER JOIN "modification_regulations" ON ("modification_regulations"."modification_regulation_id" = "measures"."measure_generating_regulation_id")
                  WHERE (("measure_generating_regulation_role" = 4))
              ORDER BY
                  "measures"."measure_generating_regulation_id" DESC,
                  "measures"."measure_generating_regulation_role" DESC,
                  "measures"."measure_type_id" DESC,
                  "measures"."goods_nomenclature_sid" DESC,
                  "measures"."geographical_area_id" DESC,
                  "measures"."geographical_area_sid" DESC,
                  "measures"."additional_code_type_id" DESC,
                  "measures"."additional_code_id" DESC,
                  "measures"."ordernumber" DESC,
                  "measures"."validity_start_date" DESC) AS "t1")) AS "measures"
      ORDER BY
          "measures"."geographical_area_id" ASC,
          "measures"."measure_type_id" ASC,
          "measures"."additional_code_type_id" ASC,
          "measures"."additional_code_id" ASC,
          "measures"."ordernumber" ASC,
          "measures"."validity_start_date" DESC) AS "t1" ON ("t1"."measure_sid" = "measures"."measure_sid"
      )
      WITH DATA;
    }
  end

  down do
    run %{
      DROP MATERIALIZED VIEW measure_real_end_dates;
    }
  end
end

