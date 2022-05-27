# frozen_string_literal: true

Sequel.migration do
  up do
    run %{
      CREATE OR REPLACE VIEW public.additional_code_type_descriptions AS
      SELECT
          additional_code_type_descriptions1.additional_code_type_id,
          additional_code_type_descriptions1.language_id,
          additional_code_type_descriptions1.description,
          additional_code_type_descriptions1."national",
          additional_code_type_descriptions1.oid,
          additional_code_type_descriptions1.operation,
          additional_code_type_descriptions1.operation_date,
          additional_code_type_descriptions1.filename
      FROM
          additional_code_type_descriptions_oplog additional_code_type_descriptions1
      WHERE (additional_code_type_descriptions1.oid IN (
              SELECT
                  max(additional_code_type_descriptions2.oid) AS max
              FROM
                  additional_code_type_descriptions_oplog additional_code_type_descriptions2
              WHERE
                  additional_code_type_descriptions1.additional_code_type_id::text = additional_code_type_descriptions2.additional_code_type_id::text
              AND additional_code_type_descriptions1.language_id::text = additional_code_type_descriptions2.language_id::text))
      AND additional_code_type_descriptions1.operation::text <> 'D'::text;
    }
  end

  down do
    run %{
      CREATE OR REPLACE VIEW public.additional_code_type_descriptions AS
      SELECT
          additional_code_type_descriptions1.additional_code_type_id,
          additional_code_type_descriptions1.language_id,
          additional_code_type_descriptions1.description,
          additional_code_type_descriptions1."national",
          additional_code_type_descriptions1.oid,
          additional_code_type_descriptions1.operation,
          additional_code_type_descriptions1.operation_date,
          additional_code_type_descriptions1.filename
      FROM
          additional_code_type_descriptions_oplog additional_code_type_descriptions1
      WHERE (additional_code_type_descriptions1.oid IN (
              SELECT
                  max(additional_code_type_descriptions2.oid) AS max
              FROM
                  additional_code_type_descriptions_oplog additional_code_type_descriptions2
              WHERE
                  additional_code_type_descriptions1.additional_code_type_id::text = additional_code_type_descriptions2.additional_code_type_id::text))
      AND additional_code_type_descriptions1.operation::text <> 'D'::text;
    }
  end
end
