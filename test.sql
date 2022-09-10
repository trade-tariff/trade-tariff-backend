CREATE MATERIALIZED VIEW measures_real_end_dates
AS SELECT * FROM measures WHERE "measures"."effective_end_date" IS NOT NULL
SELECT
    *
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
                        CASE WHEN ("measures"."validity_start_date" IS NULL) THEN
                            base_regulations.validity_start_date
                        ELSE
                            measures.validity_start_date
                        END) AS "effective_start_date",
                    (
                        CASE WHEN ("measures"."validity_end_date" IS NULL
                                AND "base_regulations"."effective_end_date" IS NOT NULL) THEN
                            base_regulations.effective_end_date
                        WHEN ("measures"."validity_end_date" IS NULL
                            AND "base_regulations"."effective_end_date" IS NULL) THEN
                            base_regulations.effective_end_date
                        ELSE
                            measures.validity_end_date
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
            "effective_start_date" DESC) AS "t1"
    UNION (
        SELECT
            *
        FROM (
            SELECT
                "measures".*,
                (
                    CASE WHEN ("measures"."validity_start_date" IS NULL) THEN
                        modification_regulations.validity_start_date
                    ELSE
                        measures.validity_start_date
                    END) AS "effective_start_date",
                (
                    CASE WHEN ("measures"."validity_end_date" IS NULL) THEN
                        modification_regulations.effective_end_date
                    ELSE
                        measures.validity_end_date
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
            "effective_start_date" DESC) AS "t1")) AS "measures"
ORDER BY
    "measures"."geographical_area_id" ASC,
    "measures"."measure_type_id" ASC,
    "measures"."additional_code_type_id" ASC,
    "measures"."additional_code_id" ASC,
    "measures"."ordernumber" ASC,
    "effective_start_date" DESC) AS "t1" ON ("t1"."measure_sid" = "measures"."measure_sid")
WITH DATA
