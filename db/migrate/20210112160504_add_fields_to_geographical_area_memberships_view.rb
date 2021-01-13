Sequel.migration do
  change do
    run %Q{
      DROP VIEW public.geographical_area_memberships;
    }

    run %Q{
      CREATE OR REPLACE VIEW public.geographical_area_memberships AS
        SELECT geographical_area_memberships1.geographical_area_sid,
        geographical_area_memberships1.geographical_area_group_sid,
        geographical_area_memberships1.validity_start_date,
        geographical_area_memberships1.validity_end_date,
        geographical_area_memberships1."national",
        geographical_area_memberships1.oid,
        geographical_area_memberships1.operation,
        geographical_area_memberships1.operation_date,
        geographical_area_memberships1.filename,
        geographical_area_memberships1.hjid,
        geographical_area_memberships1.geographical_area_hjid,
        geographical_area_memberships1.geographical_area_group_hjid
      FROM geographical_area_memberships_oplog geographical_area_memberships1
      WHERE (geographical_area_memberships1.oid IN ( SELECT max(geographical_area_memberships2.oid) AS max
              FROM geographical_area_memberships_oplog geographical_area_memberships2
              WHERE geographical_area_memberships1.geographical_area_sid = geographical_area_memberships2.geographical_area_sid AND geographical_area_memberships1.geographical_area_group_sid = geographical_area_memberships2.geographical_area_group_sid AND geographical_area_memberships1.validity_start_date = geographical_area_memberships2.validity_start_date)) AND geographical_area_memberships1.operation::text <> 'D'::text;
    }
  end
end
