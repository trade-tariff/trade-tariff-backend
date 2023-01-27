# frozen_string_literal: true

Sequel.migration do
  up do
    run %Q{
      CREATE OR REPLACE VIEW public.quota_critical_events AS
      SELECT
          quota_critical_events1.quota_definition_sid,
          quota_critical_events1.occurrence_timestamp,
          quota_critical_events1.critical_state,
          quota_critical_events1.critical_state_change_date,
          quota_critical_events1.oid,
          quota_critical_events1.operation,
          quota_critical_events1.operation_date,
          quota_critical_events1.filename
      FROM
          quota_critical_events_oplog quota_critical_events1
      WHERE (quota_critical_events1.oid IN (
              SELECT
                  max(quota_critical_events2.oid)
              FROM
                  quota_critical_events_oplog quota_critical_events2
              WHERE
                  quota_critical_events1.quota_definition_sid = quota_critical_events2.quota_definition_sid
                  AND quota_critical_events1.occurrence_timestamp = quota_critical_events2.occurrence_timestamp))
      AND quota_critical_events1.operation::text != 'D'::text;
    }
  end

  down do
    run %Q{
      CREATE OR REPLACE VIEW public.quota_critical_events
      AS SELECT quota_critical_events1.quota_definition_sid,
          quota_critical_events1.occurrence_timestamp,
          quota_critical_events1.critical_state,
          quota_critical_events1.critical_state_change_date,
          quota_critical_events1.oid,
          quota_critical_events1.operation,
          quota_critical_events1.operation_date,
          quota_critical_events1.filename
         FROM quota_critical_events_oplog quota_critical_events1
        WHERE (quota_critical_events1.oid IN ( SELECT max(quota_critical_events2.oid) AS max
                 FROM quota_critical_events_oplog quota_critical_events2
                WHERE quota_critical_events1.quota_definition_sid = quota_critical_events2.quota_definition_sid AND quota_critical_events1.occurrence_timestamp = quota_critical_events2.occurrence_timestamp
                GROUP BY quota_critical_events2.oid
                ORDER BY quota_critical_events2.oid DESC)) AND quota_critical_events1.operation::text <> 'D'::text;
    }
  end
end
