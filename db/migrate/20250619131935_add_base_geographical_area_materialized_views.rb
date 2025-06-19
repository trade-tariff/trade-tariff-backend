# frozen_string_literal: true

Sequel.migration do
  up do
    drop_view :geographical_areas
    drop_view :geographical_area_descriptions
    drop_view :geographical_area_description_periods

    create_view :geographical_areas, <<~EOVIEW, materialized: true
      SELECT geographical_areas1.geographical_area_sid,
        geographical_areas1.parent_geographical_area_group_sid,
        geographical_areas1.validity_start_date,
        geographical_areas1.validity_end_date,
        geographical_areas1.geographical_code,
        geographical_areas1.geographical_area_id,
        geographical_areas1."national",
        geographical_areas1.oid,
        geographical_areas1.operation,
        geographical_areas1.operation_date,
        geographical_areas1.filename,
        geographical_areas1.hjid
      FROM uk.geographical_areas_oplog geographical_areas1
      WHERE (geographical_areas1.oid IN ( SELECT max(geographical_areas2.oid) AS max
              FROM uk.geographical_areas_oplog geographical_areas2
              WHERE geographical_areas1.geographical_area_sid = geographical_areas2.geographical_area_sid))
                AND geographical_areas1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :geographical_area_descriptions, <<~EOVIEW, materialized: true
      SELECT geographical_area_descriptions1.geographical_area_description_period_sid,
        geographical_area_descriptions1.language_id,
        geographical_area_descriptions1.geographical_area_sid,
        geographical_area_descriptions1.geographical_area_id,
        geographical_area_descriptions1.description,
        geographical_area_descriptions1."national",
        geographical_area_descriptions1.oid,
        geographical_area_descriptions1.operation,
        geographical_area_descriptions1.operation_date,
        geographical_area_descriptions1.filename
      FROM uk.geographical_area_descriptions_oplog geographical_area_descriptions1
      WHERE (geographical_area_descriptions1.oid IN ( SELECT max(geographical_area_descriptions2.oid) AS max
              FROM uk.geographical_area_descriptions_oplog geographical_area_descriptions2
              WHERE geographical_area_descriptions1.geographical_area_description_period_sid = geographical_area_descriptions2.geographical_area_description_period_sid
                AND geographical_area_descriptions1.geographical_area_sid = geographical_area_descriptions2.geographical_area_sid))
                AND geographical_area_descriptions1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    create_view :geographical_area_description_periods, <<~EOVIEW, materialized: true
      SELECT geographical_area_description_periods1.geographical_area_description_period_sid,
        geographical_area_description_periods1.geographical_area_sid,
        geographical_area_description_periods1.validity_start_date,
        geographical_area_description_periods1.geographical_area_id,
        geographical_area_description_periods1.validity_end_date,
        geographical_area_description_periods1."national",
        geographical_area_description_periods1.oid,
        geographical_area_description_periods1.operation,
        geographical_area_description_periods1.operation_date,
        geographical_area_description_periods1.filename
      FROM uk.geographical_area_description_periods_oplog geographical_area_description_periods1
      WHERE (geographical_area_description_periods1.oid IN ( SELECT max(geographical_area_description_periods2.oid) AS max
              FROM uk.geographical_area_description_periods_oplog geographical_area_description_periods2
              WHERE geographical_area_description_periods1.geographical_area_description_period_sid = geographical_area_description_periods2.geographical_area_description_period_sid
              AND geographical_area_description_periods1.geographical_area_sid = geographical_area_description_periods2.geographical_area_sid))
              AND geographical_area_description_periods1.operation::text <> 'D'::text
      WITH DATA
    EOVIEW

    add_index :geographical_areas, :oid, unique: true
    add_index :geographical_area_descriptions, :oid, unique: true
    add_index :geographical_area_description_periods, :oid, unique: true
  end

  down do
    drop_view :geographical_areas, materialized: true
    drop_view :geographical_area_descriptions, materialized: true
    drop_view :geographical_area_description_periods, materialized: true

    create_view :geographical_areas, <<~EOVIEW
      SELECT geographical_areas1.geographical_area_sid,
        geographical_areas1.parent_geographical_area_group_sid,
        geographical_areas1.validity_start_date,
        geographical_areas1.validity_end_date,
        geographical_areas1.geographical_code,
        geographical_areas1.geographical_area_id,
        geographical_areas1."national",
        geographical_areas1.oid,
        geographical_areas1.operation,
        geographical_areas1.operation_date,
        geographical_areas1.filename,
        geographical_areas1.hjid
      FROM uk.geographical_areas_oplog geographical_areas1
      WHERE (geographical_areas1.oid IN ( SELECT max(geographical_areas2.oid) AS max
              FROM uk.geographical_areas_oplog geographical_areas2
              WHERE geographical_areas1.geographical_area_sid = geographical_areas2.geographical_area_sid))
                AND geographical_areas1.operation::text <> 'D'::text
    EOVIEW

    create_view :geographical_area_descriptions, <<~EOVIEW
      SELECT geographical_area_descriptions1.geographical_area_description_period_sid,
        geographical_area_descriptions1.language_id,
        geographical_area_descriptions1.geographical_area_sid,
        geographical_area_descriptions1.geographical_area_id,
        geographical_area_descriptions1.description,
        geographical_area_descriptions1."national",
        geographical_area_descriptions1.oid,
        geographical_area_descriptions1.operation,
        geographical_area_descriptions1.operation_date,
        geographical_area_descriptions1.filename
      FROM uk.geographical_area_descriptions_oplog geographical_area_descriptions1
      WHERE (geographical_area_descriptions1.oid IN ( SELECT max(geographical_area_descriptions2.oid) AS max
              FROM uk.geographical_area_descriptions_oplog geographical_area_descriptions2
              WHERE geographical_area_descriptions1.geographical_area_description_period_sid = geographical_area_descriptions2.geographical_area_description_period_sid
                AND geographical_area_descriptions1.geographical_area_sid = geographical_area_descriptions2.geographical_area_sid))
                AND geographical_area_descriptions1.operation::text <> 'D'::text
    EOVIEW

    create_view :geographical_area_description_periods, <<~EOVIEW
      SELECT geographical_area_description_periods1.geographical_area_description_period_sid,
        geographical_area_description_periods1.geographical_area_sid,
        geographical_area_description_periods1.validity_start_date,
        geographical_area_description_periods1.geographical_area_id,
        geographical_area_description_periods1.validity_end_date,
        geographical_area_description_periods1."national",
        geographical_area_description_periods1.oid,
        geographical_area_description_periods1.operation,
        geographical_area_description_periods1.operation_date,
        geographical_area_description_periods1.filename
      FROM uk.geographical_area_description_periods_oplog geographical_area_description_periods1
      WHERE (geographical_area_description_periods1.oid IN ( SELECT max(geographical_area_description_periods2.oid) AS max
              FROM uk.geographical_area_description_periods_oplog geographical_area_description_periods2
              WHERE geographical_area_description_periods1.geographical_area_description_period_sid = geographical_area_description_periods2.geographical_area_description_period_sid
              AND geographical_area_description_periods1.geographical_area_sid = geographical_area_description_periods2.geographical_area_sid))
              AND geographical_area_description_periods1.operation::text <> 'D'::text
    EOVIEW
  end
end
