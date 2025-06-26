# frozen_string_literal: true

Sequel.migration do
  up do
    drop_view :measure_excluded_geographical_areas
    drop_view :geographical_area_memberships

    create_view :measure_excluded_geographical_areas, <<~EOVIEW, materialized: true
      SELECT geographical_areas.measure_sid,
             geographical_areas.excluded_geographical_area,
             geographical_areas.geographical_area_sid,
             geographical_areas.oid,
             geographical_areas.operation,
             geographical_areas.operation_date,
             geographical_areas.filename
      FROM uk.measure_excluded_geographical_areas_oplog geographical_areas
      WHERE (geographical_areas.oid IN ( SELECT max(geographical_areas2.oid) AS max
      FROM uk.measure_excluded_geographical_areas_oplog geographical_areas2
      WHERE geographical_areas.measure_sid = geographical_areas2.measure_sid
            AND geographical_areas.geographical_area_sid = geographical_areas2.geographical_area_sid))
            AND geographical_areas.operation::text <> 'D'::text
    EOVIEW

    create_view :geographical_area_memberships, <<~EOVIEW, materialized: true
      SELECT memberships.geographical_area_sid,
        memberships.geographical_area_group_sid,
        memberships.validity_start_date,
        memberships.validity_end_date,
        memberships."national",
        memberships.oid,
        memberships.operation,
        memberships.operation_date,
        memberships.filename,
        memberships.hjid,
        memberships.geographical_area_hjid,
        memberships.geographical_area_group_hjid
      FROM uk.geographical_area_memberships_oplog memberships
      WHERE (memberships.oid IN ( SELECT max(memberships2.oid) AS max
              FROM uk.geographical_area_memberships_oplog memberships2
              WHERE memberships.geographical_area_sid = memberships2.geographical_area_sid
              AND memberships.geographical_area_group_sid = memberships2.geographical_area_group_sid
              AND memberships.validity_start_date = memberships2.validity_start_date))
              AND memberships.operation::text <> 'D'::text
    EOVIEW

    add_index :measure_excluded_geographical_areas, :oid, unique: true
    add_index :geographical_area_memberships, :oid, unique: true
  end

  down do
    # NOTE: Subsequent migrations duplicate this migration
    drop_view(:measure_excluded_geographical_areas, materialized: true) if MeasureExcludedGeographicalArea.actually_materialized?
    drop_view(:geographical_area_memberships, materialized: true) if GeographicalAreaMembership.actually_materialized?

    create_or_replace_view :measure_excluded_geographical_areas, <<~EOVIEW
      SELECT geographical_areas.measure_sid,
             geographical_areas.excluded_geographical_area,
             geographical_areas.geographical_area_sid,
             geographical_areas.oid,
             geographical_areas.operation,
             geographical_areas.operation_date,
             geographical_areas.filename
      FROM uk.measure_excluded_geographical_areas_oplog geographical_areas
      WHERE (geographical_areas.oid IN ( SELECT max(geographical_areas2.oid) AS max
      FROM uk.measure_excluded_geographical_areas_oplog geographical_areas2
      WHERE geographical_areas.measure_sid = geographical_areas2.measure_sid
            AND geographical_areas.geographical_area_sid = geographical_areas2.geographical_area_sid))
            AND geographical_areas.operation::text <> 'D'::text
    EOVIEW

    create_or_replace_view :geographical_area_memberships, <<~EOVIEW
      SELECT memberships.geographical_area_sid,
        memberships.geographical_area_group_sid,
        memberships.validity_start_date,
        memberships.validity_end_date,
        memberships."national",
        memberships.oid,
        memberships.operation,
        memberships.operation_date,
        memberships.filename,
        memberships.hjid,
        memberships.geographical_area_hjid,
        memberships.geographical_area_group_hjid
      FROM uk.geographical_area_memberships_oplog memberships
      WHERE (memberships.oid IN ( SELECT max(memberships2.oid) AS max
              FROM uk.geographical_area_memberships_oplog memberships2
              WHERE memberships.geographical_area_sid = memberships2.geographical_area_sid
              AND memberships.geographical_area_group_sid = memberships2.geographical_area_group_sid
              AND memberships.validity_start_date = memberships2.validity_start_date))
              AND memberships.operation::text <> 'D'::text;
    EOVIEW
  end
end
