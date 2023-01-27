Sequel.migration do
  up do
    run %{
      CREATE OR REPLACE VIEW public.quota_unsuspension_events AS
      SELECT
          quota_unsuspension_events1.quota_definition_sid,
          quota_unsuspension_events1.occurrence_timestamp,
          quota_unsuspension_events1.unsuspension_date,
          quota_unsuspension_events1.oid,
          quota_unsuspension_events1.operation,
          quota_unsuspension_events1.operation_date,
          quota_unsuspension_events1.filename
      FROM
          quota_unsuspension_events_oplog quota_unsuspension_events1
      WHERE (quota_unsuspension_events1.oid IN (
              SELECT
                  max(quota_unsuspension_events2.oid) AS max
              FROM
                  quota_unsuspension_events_oplog quota_unsuspension_events2
              WHERE
                  quota_unsuspension_events1.quota_definition_sid = quota_unsuspension_events2.quota_definition_sid
                  AND quota_unsuspension_events1.occurrence_timestamp = quota_unsuspension_events2.occurrence_timestamp))
      AND quota_unsuspension_events1.operation::text <> 'D'::text;
    }
  end

  down do
    run %{
      CREATE OR REPLACE VIEW public.quota_unsuspension_events
      AS SELECT quota_unsuspension_events1.quota_definition_sid,
          quota_unsuspension_events1.occurrence_timestamp,
          quota_unsuspension_events1.unsuspension_date,
          quota_unsuspension_events1.oid,
          quota_unsuspension_events1.operation,
          quota_unsuspension_events1.operation_date,
          quota_unsuspension_events1.filename
         FROM quota_unsuspension_events_oplog quota_unsuspension_events1
        WHERE (quota_unsuspension_events1.oid IN ( SELECT max(quota_unsuspension_events2.oid) AS max
                 FROM quota_unsuspension_events_oplog quota_unsuspension_events2
                WHERE quota_unsuspension_events1.quota_definition_sid = quota_unsuspension_events2.quota_definition_sid)) AND quota_unsuspension_events1.operation::text <> 'D'::text;
    }
  end
end
