# frozen_string_literal: true

Sequel.migration do
  up do
    run %Q{
      CREATE OR REPLACE VIEW public.quota_exhaustion_events AS
      SELECT
          quota_exhaustion_events1.quota_definition_sid,
          quota_exhaustion_events1.occurrence_timestamp,
          quota_exhaustion_events1.exhaustion_date,
          quota_exhaustion_events1.oid,
          quota_exhaustion_events1.operation,
          quota_exhaustion_events1.operation_date,
          quota_exhaustion_events1.filename
      FROM
          quota_exhaustion_events_oplog quota_exhaustion_events1
      WHERE (quota_exhaustion_events1.oid IN (
              SELECT
                  max(quota_exhaustion_events2.oid)
              FROM
                  quota_exhaustion_events_oplog quota_exhaustion_events2
              WHERE
                  quota_exhaustion_events1.quota_definition_sid = quota_exhaustion_events2.quota_definition_sid
                  AND quota_exhaustion_events1.occurrence_timestamp = quota_exhaustion_events2.occurrence_timestamp))
      AND quota_exhaustion_events1.operation::text != 'D'::text;
    }
  end

  down do
    run %Q{
      CREATE OR REPLACE VIEW public.quota_exhaustion_events
      AS SELECT quota_exhaustion_events1.quota_definition_sid,
          quota_exhaustion_events1.occurrence_timestamp,
          quota_exhaustion_events1.exhaustion_date,
          quota_exhaustion_events1.oid,
          quota_exhaustion_events1.operation,
          quota_exhaustion_events1.operation_date,
          quota_exhaustion_events1.filename
         FROM quota_exhaustion_events_oplog quota_exhaustion_events1
        WHERE (quota_exhaustion_events1.oid IN ( SELECT max(quota_exhaustion_events2.oid) AS max
                 FROM quota_exhaustion_events_oplog quota_exhaustion_events2
                WHERE quota_exhaustion_events1.quota_definition_sid = quota_exhaustion_events2.quota_definition_sid)) AND quota_exhaustion_events1.operation::text <> 'D'::text;
    }
  end
end
