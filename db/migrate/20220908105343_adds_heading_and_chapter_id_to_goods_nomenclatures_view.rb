Sequel.migration do
  up do
    run %{
      CREATE OR REPLACE VIEW public.goods_nomenclatures
      AS SELECT goods_nomenclatures1.goods_nomenclature_sid,
          goods_nomenclatures1.goods_nomenclature_item_id,
          goods_nomenclatures1.producline_suffix,
          goods_nomenclatures1.validity_start_date,
          goods_nomenclatures1.validity_end_date,
          goods_nomenclatures1.statistical_indicator,
          goods_nomenclatures1.oid,
          goods_nomenclatures1.operation,
          goods_nomenclatures1.operation_date,
          goods_nomenclatures1.filename,
          goods_nomenclatures1.path,
          (
              CASE WHEN "goods_nomenclatures1"."goods_nomenclature_item_id" LIKE '__00000000' THEN
                  NULL
              ELSE
              LEFT ("goods_nomenclatures1"."goods_nomenclature_item_id",
                  4)
              END) AS "heading_short_code",
          (
              LEFT ("goods_nomenclatures1"."goods_nomenclature_item_id",
                  2)
          ) AS "chapter_short_code"
      FROM
          goods_nomenclatures_oplog goods_nomenclatures1
      WHERE (goods_nomenclatures1.oid IN (
              SELECT
                  max(goods_nomenclatures2.oid) AS max
              FROM
                  goods_nomenclatures_oplog goods_nomenclatures2
              WHERE
                  goods_nomenclatures1.goods_nomenclature_sid = goods_nomenclatures2.goods_nomenclature_sid))
          AND goods_nomenclatures1.operation::text <> 'D'::text;
    }
  end

  down do
    run %{
      DROP VIEW public.goods_nomenclatures;
      CREATE OR REPLACE VIEW public.goods_nomenclatures AS
      SELECT
          goods_nomenclatures1.goods_nomenclature_sid,
          goods_nomenclatures1.goods_nomenclature_item_id,
          goods_nomenclatures1.producline_suffix,
          goods_nomenclatures1.validity_start_date,
          goods_nomenclatures1.validity_end_date,
          goods_nomenclatures1.statistical_indicator,
          goods_nomenclatures1.oid,
          goods_nomenclatures1.operation,
          goods_nomenclatures1.operation_date,
          goods_nomenclatures1.filename,
          goods_nomenclatures1.path
      FROM
          goods_nomenclatures_oplog goods_nomenclatures1
      WHERE (goods_nomenclatures1.oid IN (
              SELECT
                  max(goods_nomenclatures2.oid) AS max
              FROM
                  goods_nomenclatures_oplog goods_nomenclatures2
              WHERE
                  goods_nomenclatures1.goods_nomenclature_sid = goods_nomenclatures2.goods_nomenclature_sid))
      AND goods_nomenclatures1.operation::text <> 'D'::text;
    }
  end
end
