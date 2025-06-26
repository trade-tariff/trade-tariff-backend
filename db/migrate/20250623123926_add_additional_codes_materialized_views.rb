# frozen_string_literal: true

Sequel.migration do
  up do
    drop_view :additional_codes
    drop_view :additional_code_types
    drop_view :additional_code_type_measure_types
    drop_view :additional_code_type_descriptions
    drop_view :additional_code_descriptions
    drop_view :additional_code_description_periods

    create_view :additional_codes, <<~EOVIEW, materialized: true
      SELECT additional_codes1.additional_code_sid,
          additional_codes1.additional_code_type_id,
          additional_codes1.additional_code,
          additional_codes1.validity_start_date,
          additional_codes1.validity_end_date,
          additional_codes1."national",
          additional_codes1.oid,
          additional_codes1.operation,
          additional_codes1.operation_date,
          additional_codes1.filename
        FROM additional_codes_oplog additional_codes1
        WHERE (additional_codes1.oid IN ( SELECT max(additional_codes2.oid) AS max
                FROM additional_codes_oplog additional_codes2
                WHERE additional_codes1.additional_code_sid = additional_codes2.additional_code_sid)) AND additional_codes1.operation::text <> 'D'::text
        WITH DATA
    EOVIEW

    create_view :additional_code_types, <<~EOVIEW, materialized: true
      SELECT additional_code_types1.additional_code_type_id,
        additional_code_types1.validity_start_date,
        additional_code_types1.validity_end_date,
        additional_code_types1.application_code,
        additional_code_types1.meursing_table_plan_id,
        additional_code_types1."national",
        additional_code_types1.oid,
        additional_code_types1.operation,
        additional_code_types1.operation_date,
        additional_code_types1.filename
       FROM additional_code_types_oplog additional_code_types1
      WHERE (additional_code_types1.oid IN ( SELECT max(additional_code_types2.oid) AS max
               FROM additional_code_types_oplog additional_code_types2
              WHERE additional_code_types1.additional_code_type_id::text = additional_code_types2.additional_code_type_id::text)) AND additional_code_types1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :additional_code_type_measure_types, <<~EOVIEW, materialized: true
      SELECT additional_code_type_measure_types1.measure_type_id,
        additional_code_type_measure_types1.additional_code_type_id,
        additional_code_type_measure_types1.validity_start_date,
        additional_code_type_measure_types1.validity_end_date,
        additional_code_type_measure_types1."national",
        additional_code_type_measure_types1.oid,
        additional_code_type_measure_types1.operation,
        additional_code_type_measure_types1.operation_date,
        additional_code_type_measure_types1.filename
      FROM additional_code_type_measure_types_oplog additional_code_type_measure_types1
      WHERE (additional_code_type_measure_types1.oid IN ( SELECT max(additional_code_type_measure_types2.oid) AS max
               FROM additional_code_type_measure_types_oplog additional_code_type_measure_types2
              WHERE additional_code_type_measure_types1.measure_type_id::text = additional_code_type_measure_types2.measure_type_id::text AND additional_code_type_measure_types1.additional_code_type_id::text = additional_code_type_measure_types2.additional_code_type_id::text)) AND additional_code_type_measure_types1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :additional_code_type_descriptions, <<~EOVIEW, materialized: true
      SELECT additional_code_type_descriptions1.additional_code_type_id,
          additional_code_type_descriptions1.language_id,
          additional_code_type_descriptions1.description,
          additional_code_type_descriptions1."national",
          additional_code_type_descriptions1.oid,
          additional_code_type_descriptions1.operation,
          additional_code_type_descriptions1.operation_date,
          additional_code_type_descriptions1.filename
        FROM additional_code_type_descriptions_oplog additional_code_type_descriptions1
        WHERE (additional_code_type_descriptions1.oid IN ( SELECT max(additional_code_type_descriptions2.oid) AS max
                 FROM additional_code_type_descriptions_oplog additional_code_type_descriptions2
                WHERE additional_code_type_descriptions1.additional_code_type_id::text = additional_code_type_descriptions2.additional_code_type_id::text AND additional_code_type_descriptions1.language_id::text = additional_code_type_descriptions2.language_id::text)) AND additional_code_type_descriptions1.operation::text <> 'D'::text
       WITH DATA
    EOVIEW

    create_view :additional_code_descriptions, <<~EOVIEW, materialized: true
      SELECT additional_code_descriptions1.additional_code_description_period_sid,
          additional_code_descriptions1.language_id,
          additional_code_descriptions1.additional_code_sid,
          additional_code_descriptions1.additional_code_type_id,
          additional_code_descriptions1.additional_code,
          additional_code_descriptions1.description,
          additional_code_descriptions1."national",
          additional_code_descriptions1.oid,
          additional_code_descriptions1.operation,
          additional_code_descriptions1.operation_date,
          additional_code_descriptions1.filename
        FROM additional_code_descriptions_oplog additional_code_descriptions1
        WHERE (additional_code_descriptions1.oid IN ( SELECT max(additional_code_descriptions2.oid) AS max
                 FROM additional_code_descriptions_oplog additional_code_descriptions2
                WHERE additional_code_descriptions1.additional_code_description_period_sid = additional_code_descriptions2.additional_code_description_period_sid AND additional_code_descriptions1.additional_code_sid = additional_code_descriptions2.additional_code_sid)) AND additional_code_descriptions1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :additional_code_description_periods, <<~EOVIEW, materialized: true
      SELECT additional_code_description_periods1.additional_code_description_period_sid,
          additional_code_description_periods1.additional_code_sid,
          additional_code_description_periods1.additional_code_type_id,
          additional_code_description_periods1.additional_code,
          additional_code_description_periods1.validity_start_date,
          additional_code_description_periods1.validity_end_date,
          additional_code_description_periods1.oid,
          additional_code_description_periods1.operation,
          additional_code_description_periods1.operation_date,
          additional_code_description_periods1.filename
        FROM additional_code_description_periods_oplog additional_code_description_periods1
        WHERE (additional_code_description_periods1.oid IN ( SELECT max(additional_code_description_periods2.oid) AS max
               FROM additional_code_description_periods_oplog additional_code_description_periods2
              WHERE additional_code_description_periods1.additional_code_description_period_sid = additional_code_description_periods2.additional_code_description_period_sid AND additional_code_description_periods1.additional_code_sid = additional_code_description_periods2.additional_code_sid AND additional_code_description_periods1.additional_code_type_id::text = additional_code_description_periods2.additional_code_type_id::text)) AND additional_code_description_periods1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    add_index :additional_codes, :oid, unique: true
    add_index :additional_code_types, :oid, unique: true
    add_index :additional_code_type_measure_types, :oid, unique: true
    add_index :additional_code_type_descriptions, :oid, unique: true
    add_index :additional_code_descriptions, :oid, unique: true
    add_index :additional_code_description_periods, :oid, unique: true
  end

  down do
    drop_view :additional_codes, materialized: true
    drop_view :additional_code_types, materialized: true
    drop_view :additional_code_type_measure_types, materialized: true
    drop_view :additional_code_type_descriptions, materialized: true
    drop_view :additional_code_descriptions, materialized: true
    drop_view :additional_code_description_periods, materialized: true

    create_view :additional_codes, <<~EOVIEW
      SELECT additional_codes1.additional_code_sid,
          additional_codes1.additional_code_type_id,
          additional_codes1.additional_code,
          additional_codes1.validity_start_date,
          additional_codes1.validity_end_date,
          additional_codes1."national",
          additional_codes1.oid,
          additional_codes1.operation,
          additional_codes1.operation_date,
          additional_codes1.filename
        FROM additional_codes_oplog additional_codes1
        WHERE (additional_codes1.oid IN ( SELECT max(additional_codes2.oid) AS max
                FROM additional_codes_oplog additional_codes2
                WHERE additional_codes1.additional_code_sid = additional_codes2.additional_code_sid)) AND additional_codes1.operation::text <> 'D'::text
    EOVIEW

    create_view :additional_code_types, <<~EOVIEW
      SELECT additional_code_types1.additional_code_type_id,
        additional_code_types1.validity_start_date,
        additional_code_types1.validity_end_date,
        additional_code_types1.application_code,
        additional_code_types1.meursing_table_plan_id,
        additional_code_types1."national",
        additional_code_types1.oid,
        additional_code_types1.operation,
        additional_code_types1.operation_date,
        additional_code_types1.filename
       FROM additional_code_types_oplog additional_code_types1
      WHERE (additional_code_types1.oid IN ( SELECT max(additional_code_types2.oid) AS max
               FROM additional_code_types_oplog additional_code_types2
              WHERE additional_code_types1.additional_code_type_id::text = additional_code_types2.additional_code_type_id::text)) AND additional_code_types1.operation::text <> 'D'::text
    EOVIEW

    create_view :additional_code_type_measure_types, <<~EOVIEW
      SELECT additional_code_type_measure_types1.measure_type_id,
        additional_code_type_measure_types1.additional_code_type_id,
        additional_code_type_measure_types1.validity_start_date,
        additional_code_type_measure_types1.validity_end_date,
        additional_code_type_measure_types1."national",
        additional_code_type_measure_types1.oid,
        additional_code_type_measure_types1.operation,
        additional_code_type_measure_types1.operation_date,
        additional_code_type_measure_types1.filename
      FROM additional_code_type_measure_types_oplog additional_code_type_measure_types1
      WHERE (additional_code_type_measure_types1.oid IN ( SELECT max(additional_code_type_measure_types2.oid) AS max
               FROM additional_code_type_measure_types_oplog additional_code_type_measure_types2
              WHERE additional_code_type_measure_types1.measure_type_id::text = additional_code_type_measure_types2.measure_type_id::text AND additional_code_type_measure_types1.additional_code_type_id::text = additional_code_type_measure_types2.additional_code_type_id::text)) AND additional_code_type_measure_types1.operation::text <> 'D'::text
    EOVIEW

    create_view :additional_code_type_descriptions, <<~EOVIEW
      SELECT additional_code_type_descriptions1.additional_code_type_id,
          additional_code_type_descriptions1.language_id,
          additional_code_type_descriptions1.description,
          additional_code_type_descriptions1."national",
          additional_code_type_descriptions1.oid,
          additional_code_type_descriptions1.operation,
          additional_code_type_descriptions1.operation_date,
          additional_code_type_descriptions1.filename
        FROM additional_code_type_descriptions_oplog additional_code_type_descriptions1
        WHERE (additional_code_type_descriptions1.oid IN ( SELECT max(additional_code_type_descriptions2.oid) AS max
                 FROM additional_code_type_descriptions_oplog additional_code_type_descriptions2
                WHERE additional_code_type_descriptions1.additional_code_type_id::text = additional_code_type_descriptions2.additional_code_type_id::text AND additional_code_type_descriptions1.language_id::text = additional_code_type_descriptions2.language_id::text)) AND additional_code_type_descriptions1.operation::text <> 'D'::text
    EOVIEW

    create_view :additional_code_descriptions, <<~EOVIEW
      SELECT additional_code_descriptions1.additional_code_description_period_sid,
          additional_code_descriptions1.language_id,
          additional_code_descriptions1.additional_code_sid,
          additional_code_descriptions1.additional_code_type_id,
          additional_code_descriptions1.additional_code,
          additional_code_descriptions1.description,
          additional_code_descriptions1."national",
          additional_code_descriptions1.oid,
          additional_code_descriptions1.operation,
          additional_code_descriptions1.operation_date,
          additional_code_descriptions1.filename
        FROM additional_code_descriptions_oplog additional_code_descriptions1
        WHERE (additional_code_descriptions1.oid IN ( SELECT max(additional_code_descriptions2.oid) AS max
                 FROM additional_code_descriptions_oplog additional_code_descriptions2
                WHERE additional_code_descriptions1.additional_code_description_period_sid = additional_code_descriptions2.additional_code_description_period_sid AND additional_code_descriptions1.additional_code_sid = additional_code_descriptions2.additional_code_sid)) AND additional_code_descriptions1.operation::text <> 'D'::text
    EOVIEW

    create_view :additional_code_description_periods, <<~EOVIEW
      SELECT additional_code_description_periods1.additional_code_description_period_sid,
          additional_code_description_periods1.additional_code_sid,
          additional_code_description_periods1.additional_code_type_id,
          additional_code_description_periods1.additional_code,
          additional_code_description_periods1.validity_start_date,
          additional_code_description_periods1.validity_end_date,
          additional_code_description_periods1.oid,
          additional_code_description_periods1.operation,
          additional_code_description_periods1.operation_date,
          additional_code_description_periods1.filename
        FROM additional_code_description_periods_oplog additional_code_description_periods1
        WHERE (additional_code_description_periods1.oid IN ( SELECT max(additional_code_description_periods2.oid) AS max
               FROM additional_code_description_periods_oplog additional_code_description_periods2
              WHERE additional_code_description_periods1.additional_code_description_period_sid = additional_code_description_periods2.additional_code_description_period_sid AND additional_code_description_periods1.additional_code_sid = additional_code_description_periods2.additional_code_sid AND additional_code_description_periods1.additional_code_type_id::text = additional_code_description_periods2.additional_code_type_id::text)) AND additional_code_description_periods1.operation::text <> 'D'::text
    EOVIEW
  end
end
