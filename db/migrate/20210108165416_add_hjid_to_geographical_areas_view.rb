Sequel.migration do
  change do
    run %Q{
      DROP VIEW public.geographical_areas;
    }

    run %Q{
      CREATE OR REPLACE VIEW public.geographical_areas AS
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
      FROM geographical_areas_oplog geographical_areas1
      WHERE (geographical_areas1.oid IN ( SELECT max(geographical_areas2.oid) AS max
          FROM geographical_areas_oplog geographical_areas2
          WHERE geographical_areas1.geographical_area_sid = geographical_areas2.geographical_area_sid)) AND geographical_areas1.operation::text <> 'D'::text;
    }
  end
end
