Sequel.migration do
  up do
    run 'DROP VIEW public.footnote_association_additional_codes;'
    run 'DROP VIEW public.footnote_association_erns;'
    run 'DROP VIEW public.footnote_association_goods_nomenclatures;'
    run 'DROP VIEW public.footnote_association_measures;'
    run 'DROP VIEW public.footnote_association_meursing_headings;'
    run 'DROP VIEW public.footnote_description_periods;'
    run 'DROP VIEW public.footnote_descriptions;'
    run 'DROP VIEW public.footnote_type_descriptions;'
    run 'DROP VIEW public.footnote_types;'
    run 'DROP VIEW public.footnotes;'

    alter_table :footnote_association_additional_codes_oplog do
      set_column_type :footnote_type_id, String, size: 3
    end
    alter_table :footnote_association_erns_oplog do
      set_column_type :footnote_type, String, size: 3
    end
    alter_table :footnote_association_goods_nomenclatures_oplog do
      set_column_type :footnote_type, String, size: 3
    end
    alter_table :footnote_association_measures_oplog do
      set_column_type :footnote_type_id, String, size: 3
    end
    alter_table :footnote_association_meursing_headings_oplog do
      set_column_type :footnote_type, String, size: 3
    end
    alter_table :footnote_description_periods_oplog do
      set_column_type :footnote_type_id, String, size: 3
    end
    alter_table :footnote_descriptions_oplog do
      set_column_type :footnote_type_id, String, size: 3
    end
    alter_table :footnote_type_descriptions_oplog do
      set_column_type :footnote_type_id, String, size: 3
    end
    alter_table :footnote_types_oplog do
      set_column_type :footnote_type_id, String, size: 3
    end
    alter_table :footnotes_oplog do
      set_column_type :footnote_type_id, String, size: 3
    end

    # echo "\sv footnote_association_additional_codes" | psql -h localhost tariff_development >> views.sql
    # echo "\sv footnote_association_erns" | psql -h localhost tariff_development  >> views.sql
    # echo "\sv footnote_association_goods_nomenclatures" | psql -h localhost tariff_development >> views.sql
    # echo "\sv footnote_association_measures" | psql -h localhost tariff_development >> views.sql
    # echo "\sv footnote_association_meursing_headings" | psql -h localhost tariff_development >> views.sql
    # echo "\sv footnote_description_periods" | psql -h localhost tariff_development >> views.sql
    # echo "\sv footnote_descriptions" | psql -h localhost tariff_development >> views.sql
    # echo "\sv footnote_type_descriptions" | psql -h localhost tariff_development  >> views.sql
    # echo "\sv footnote_types" | psql -h localhost tariff_development >> views.sql
    # echo "\sv footnotes" | psql -h localhost tariff_development >> views.sql
    run %{
      CREATE OR REPLACE VIEW public.footnote_association_additional_codes AS
      SELECT
          footnote_association_additional_codes1.additional_code_sid,
          footnote_association_additional_codes1.footnote_type_id,
          footnote_association_additional_codes1.footnote_id,
          footnote_association_additional_codes1.validity_start_date,
          footnote_association_additional_codes1.validity_end_date,
          footnote_association_additional_codes1.additional_code_type_id,
          footnote_association_additional_codes1.additional_code,
          footnote_association_additional_codes1.oid,
          footnote_association_additional_codes1.operation,
          footnote_association_additional_codes1.operation_date,
          footnote_association_additional_codes1.filename
      FROM
          footnote_association_additional_codes_oplog footnote_association_additional_codes1
      WHERE (footnote_association_additional_codes1.oid IN (
              SELECT
                  max(footnote_association_additional_codes2.oid) AS max
              FROM
                  footnote_association_additional_codes_oplog footnote_association_additional_codes2
              WHERE
                  footnote_association_additional_codes1.footnote_id::text = footnote_association_additional_codes2.footnote_id::text
                  AND footnote_association_additional_codes1.footnote_type_id::text = footnote_association_additional_codes2.footnote_type_id::text
                  AND footnote_association_additional_codes1.additional_code_sid = footnote_association_additional_codes2.additional_code_sid))
      AND footnote_association_additional_codes1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnote_association_erns AS
      SELECT
          footnote_association_erns1.export_refund_nomenclature_sid,
          footnote_association_erns1.footnote_type,
          footnote_association_erns1.footnote_id,
          footnote_association_erns1.validity_start_date,
          footnote_association_erns1.validity_end_date,
          footnote_association_erns1.goods_nomenclature_item_id,
          footnote_association_erns1.additional_code_type,
          footnote_association_erns1.export_refund_code,
          footnote_association_erns1.productline_suffix,
          footnote_association_erns1.oid,
          footnote_association_erns1.operation,
          footnote_association_erns1.operation_date,
          footnote_association_erns1.filename
      FROM
          footnote_association_erns_oplog footnote_association_erns1
      WHERE (footnote_association_erns1.oid IN (
              SELECT
                  max(footnote_association_erns2.oid) AS max
              FROM
                  footnote_association_erns_oplog footnote_association_erns2
              WHERE
                  footnote_association_erns1.export_refund_nomenclature_sid = footnote_association_erns2.export_refund_nomenclature_sid
                  AND footnote_association_erns1.footnote_id::text = footnote_association_erns2.footnote_id::text
                  AND footnote_association_erns1.footnote_type::text = footnote_association_erns2.footnote_type::text
                  AND footnote_association_erns1.validity_start_date = footnote_association_erns2.validity_start_date))
      AND footnote_association_erns1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnote_association_goods_nomenclatures AS
      SELECT
          footnote_association_goods_nomenclatures1.goods_nomenclature_sid,
          footnote_association_goods_nomenclatures1.footnote_type,
          footnote_association_goods_nomenclatures1.footnote_id,
          footnote_association_goods_nomenclatures1.validity_start_date,
          footnote_association_goods_nomenclatures1.validity_end_date,
          footnote_association_goods_nomenclatures1.goods_nomenclature_item_id,
          footnote_association_goods_nomenclatures1.productline_suffix,
          footnote_association_goods_nomenclatures1."national",
          footnote_association_goods_nomenclatures1.oid,
          footnote_association_goods_nomenclatures1.operation,
          footnote_association_goods_nomenclatures1.operation_date,
          footnote_association_goods_nomenclatures1.filename
      FROM
          footnote_association_goods_nomenclatures_oplog footnote_association_goods_nomenclatures1
      WHERE (footnote_association_goods_nomenclatures1.oid IN (
              SELECT
                  max(footnote_association_goods_nomenclatures2.oid) AS max
              FROM
                  footnote_association_goods_nomenclatures_oplog footnote_association_goods_nomenclatures2
              WHERE
                  footnote_association_goods_nomenclatures1.footnote_id::text = footnote_association_goods_nomenclatures2.footnote_id::text
                  AND footnote_association_goods_nomenclatures1.footnote_type::text = footnote_association_goods_nomenclatures2.footnote_type::text
                  AND footnote_association_goods_nomenclatures1.goods_nomenclature_sid = footnote_association_goods_nomenclatures2.goods_nomenclature_sid))
      AND footnote_association_goods_nomenclatures1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnote_association_measures AS
      SELECT
          footnote_association_measures1.measure_sid,
          footnote_association_measures1.footnote_type_id,
          footnote_association_measures1.footnote_id,
          footnote_association_measures1."national",
          footnote_association_measures1.oid,
          footnote_association_measures1.operation,
          footnote_association_measures1.operation_date,
          footnote_association_measures1.filename
      FROM
          footnote_association_measures_oplog footnote_association_measures1
      WHERE (footnote_association_measures1.oid IN (
              SELECT
                  max(footnote_association_measures2.oid) AS max
              FROM
                  footnote_association_measures_oplog footnote_association_measures2
              WHERE
                  footnote_association_measures1.measure_sid = footnote_association_measures2.measure_sid
                  AND footnote_association_measures1.footnote_id::text = footnote_association_measures2.footnote_id::text
                  AND footnote_association_measures1.footnote_type_id::text = footnote_association_measures2.footnote_type_id::text))
      AND footnote_association_measures1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnote_association_meursing_headings AS
      SELECT
          footnote_association_meursing_headings1.meursing_table_plan_id,
          footnote_association_meursing_headings1.meursing_heading_number,
          footnote_association_meursing_headings1.row_column_code,
          footnote_association_meursing_headings1.footnote_type,
          footnote_association_meursing_headings1.footnote_id,
          footnote_association_meursing_headings1.validity_start_date,
          footnote_association_meursing_headings1.validity_end_date,
          footnote_association_meursing_headings1.oid,
          footnote_association_meursing_headings1.operation,
          footnote_association_meursing_headings1.operation_date,
          footnote_association_meursing_headings1.filename
      FROM
          footnote_association_meursing_headings_oplog footnote_association_meursing_headings1
      WHERE (footnote_association_meursing_headings1.oid IN (
              SELECT
                  max(footnote_association_meursing_headings2.oid) AS max
              FROM
                  footnote_association_meursing_headings_oplog footnote_association_meursing_headings2
              WHERE
                  footnote_association_meursing_headings1.footnote_id::text = footnote_association_meursing_headings2.footnote_id::text
                  AND footnote_association_meursing_headings1.meursing_table_plan_id::text = footnote_association_meursing_headings2.meursing_table_plan_id::text))
      AND footnote_association_meursing_headings1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnote_description_periods AS
      SELECT
          footnote_description_periods1.footnote_description_period_sid,
          footnote_description_periods1.footnote_type_id,
          footnote_description_periods1.footnote_id,
          footnote_description_periods1.validity_start_date,
          footnote_description_periods1.validity_end_date,
          footnote_description_periods1."national",
          footnote_description_periods1.oid,
          footnote_description_periods1.operation,
          footnote_description_periods1.operation_date,
          footnote_description_periods1.filename
      FROM
          footnote_description_periods_oplog footnote_description_periods1
      WHERE (footnote_description_periods1.oid IN (
              SELECT
                  max(footnote_description_periods2.oid) AS max
              FROM
                  footnote_description_periods_oplog footnote_description_periods2
              WHERE
                  footnote_description_periods1.footnote_id::text = footnote_description_periods2.footnote_id::text
                  AND footnote_description_periods1.footnote_type_id::text = footnote_description_periods2.footnote_type_id::text
                  AND footnote_description_periods1.footnote_description_period_sid = footnote_description_periods2.footnote_description_period_sid))
      AND footnote_description_periods1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnote_descriptions AS
      SELECT
          footnote_descriptions1.footnote_description_period_sid,
          footnote_descriptions1.footnote_type_id,
          footnote_descriptions1.footnote_id,
          footnote_descriptions1.language_id,
          footnote_descriptions1.description,
          footnote_descriptions1."national",
          footnote_descriptions1.oid,
          footnote_descriptions1.operation,
          footnote_descriptions1.operation_date,
          footnote_descriptions1.filename
      FROM
          footnote_descriptions_oplog footnote_descriptions1
      WHERE (footnote_descriptions1.oid IN (
              SELECT
                  max(footnote_descriptions2.oid) AS max
              FROM
                  footnote_descriptions_oplog footnote_descriptions2
              WHERE
                  footnote_descriptions1.footnote_description_period_sid = footnote_descriptions2.footnote_description_period_sid
                  AND footnote_descriptions1.footnote_id::text = footnote_descriptions2.footnote_id::text
                  AND footnote_descriptions1.footnote_type_id::text = footnote_descriptions2.footnote_type_id::text))
      AND footnote_descriptions1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnote_type_descriptions AS
      SELECT
          footnote_type_descriptions1.footnote_type_id,
          footnote_type_descriptions1.language_id,
          footnote_type_descriptions1.description,
          footnote_type_descriptions1."national",
          footnote_type_descriptions1.oid,
          footnote_type_descriptions1.operation,
          footnote_type_descriptions1.operation_date,
          footnote_type_descriptions1.filename
      FROM
          footnote_type_descriptions_oplog footnote_type_descriptions1
      WHERE (footnote_type_descriptions1.oid IN (
              SELECT
                  max(footnote_type_descriptions2.oid) AS max
              FROM
                  footnote_type_descriptions_oplog footnote_type_descriptions2
              WHERE
                  footnote_type_descriptions1.footnote_type_id::text = footnote_type_descriptions2.footnote_type_id::text))
      AND footnote_type_descriptions1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnote_types AS
      SELECT
          footnote_types1.footnote_type_id,
          footnote_types1.application_code,
          footnote_types1.validity_start_date,
          footnote_types1.validity_end_date,
          footnote_types1."national",
          footnote_types1.oid,
          footnote_types1.operation,
          footnote_types1.operation_date,
          footnote_types1.filename
      FROM
          footnote_types_oplog footnote_types1
      WHERE (footnote_types1.oid IN (
              SELECT
                  max(footnote_types2.oid) AS max
              FROM
                  footnote_types_oplog footnote_types2
              WHERE
                  footnote_types1.footnote_type_id::text = footnote_types2.footnote_type_id::text))
      AND footnote_types1.operation::text <> 'D'::text;

      CREATE OR REPLACE VIEW public.footnotes AS
      SELECT
          footnotes1.footnote_id,
          footnotes1.footnote_type_id,
          footnotes1.validity_start_date,
          footnotes1.validity_end_date,
          footnotes1."national",
          footnotes1.oid,
          footnotes1.operation,
          footnotes1.operation_date,
          footnotes1.filename
      FROM
          footnotes_oplog footnotes1
      WHERE (footnotes1.oid IN (
              SELECT
                  max(footnotes2.oid) AS max
              FROM
                  footnotes_oplog footnotes2
              WHERE
                  footnotes1.footnote_type_id::text = footnotes2.footnote_type_id::text
                  AND footnotes1.footnote_id::text = footnotes2.footnote_id::text))
      AND footnotes1.operation::text <> 'D'::text;
    }
  end

  down do
    # This cannot be backed out
  end
end
