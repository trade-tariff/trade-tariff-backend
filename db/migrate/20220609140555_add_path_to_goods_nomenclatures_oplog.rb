# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :goods_nomenclatures_oplog do
      add_column :path, 'int[]', default: [], null: false
    end

    add_index :goods_nomenclatures_oplog, :path, type: :gin

    run %{
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

  down do
    # We need to DROP the view and recreated because we're removing columns from it
    run %{
      DROP VIEW public.goods_nomenclatures;
      CREATE VIEW public.goods_nomenclatures AS
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
          goods_nomenclatures1.filename
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

    alter_table :goods_nomenclatures_oplog do
      drop_column :path
    end
  end
end
