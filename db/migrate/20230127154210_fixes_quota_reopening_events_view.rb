# frozen_string_literal: true

Sequel.migration do
  up do
    run %Q{
      CREATE OR REPLACE VIEW public.quota_reopening_events AS
      SELECT
          quota_reopening_events1.quota_definition_sid,
          quota_reopening_events1.occurrence_timestamp,
          quota_reopening_events1.reopening_date,
          quota_reopening_events1.oid,
          quota_reopening_events1.operation,
          quota_reopening_events1.operation_date,
          quota_reopening_events1.filename
      FROM
          quota_reopening_events_oplog quota_reopening_events1
      WHERE (quota_reopening_events1.oid IN (
              SELECT max(quota_reopening_events2.oid)
              FROM
                  quota_reopening_events_oplog quota_reopening_events2
              WHERE
                  quota_reopening_events1.quota_definition_sid = quota_reopening_events2.quota_definition_sid
                  AND quota_reopening_events1.occurrence_timestamp = quota_reopening_events2.occurrence_timestamp))
      AND quota_reopening_events1.operation::text != 'D'::text;
    }
  end

  down do
    run %Q{
      CREATE OR REPLACE VIEW public.quota_reopening_events
      AS SELECT quota_reopening_events1.quota_definition_sid,
          quota_reopening_events1.occurrence_timestamp,
          quota_reopening_events1.reopening_date,
          quota_reopening_events1.oid,
          quota_reopening_events1.operation,
          quota_reopening_events1.operation_date,
          quota_reopening_events1.filename
         FROM quota_reopening_events_oplog quota_reopening_events1
        WHERE (quota_reopening_events1.oid IN ( SELECT max(quota_reopening_events2.oid) AS max
                 FROM quota_reopening_events_oplog quota_reopening_events2
                WHERE quota_reopening_events1.quota_definition_sid = quota_reopening_events2.quota_definition_sid)) AND quota_reopening_events1.operation::text <> 'D'::text;
    }
  end
end
