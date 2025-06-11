# frozen_string_literal: true

Sequel.migration do
  change do
    run %Q{
      DROP VIEW geographical_area_memberships;
    }

    run %Q{
       CREATE MATERIALIZED VIEW geographical_area_memberships AS
       SELECT geographical_area_sid,
        geographical_area_group_sid,
        validity_start_date,
        validity_end_date,
        "national",
        oid,
        operation,
        operation_date,
        filename,
        hjid,
        geographical_area_hjid,
        geographical_area_group_hjid
      FROM geographical_area_memberships_oplog geographical_area_memberships1
      WHERE (oid IN ( SELECT max(geographical_area_memberships2.oid) AS max
              FROM geographical_area_memberships_oplog geographical_area_memberships2
              WHERE 
                geographical_area_memberships1.geographical_area_sid = geographical_area_memberships2.geographical_area_sid 
              AND 
                geographical_area_memberships1.geographical_area_group_sid = geographical_area_memberships2.geographical_area_group_sid 
              AND 
                geographical_area_memberships1.validity_start_date = geographical_area_memberships2.validity_start_date)) AND operation::text <> 'D'::text;
    }
  end
end
