# frozen_string_literal: true

Sequel.migration do
  up do
    run %{
      CREATE OR REPLACE VIEW public.quota_closed_and_transferred_events AS
        SELECT
            quota_closed_and_transferred_events1.oid,
            quota_closed_and_transferred_events1.quota_definition_sid,
            quota_closed_and_transferred_events1.target_quota_definition_sid,
            quota_closed_and_transferred_events1.occurrence_timestamp,
            quota_closed_and_transferred_events1.operation,
            quota_closed_and_transferred_events1.operation_date,
            quota_closed_and_transferred_events1.transferred_amount,
            quota_closed_and_transferred_events1.closing_date,
            quota_closed_and_transferred_events1.filename
        FROM
            quota_closed_and_transferred_events_oplog quota_closed_and_transferred_events1
        WHERE (quota_closed_and_transferred_events1.oid IN (
                SELECT
                    max(quota_closed_and_transferred_events2.oid) AS max
                FROM
                    quota_closed_and_transferred_events_oplog quota_closed_and_transferred_events2
                WHERE
                    quota_closed_and_transferred_events1.quota_definition_sid = quota_closed_and_transferred_events2.quota_definition_sid
                    AND quota_closed_and_transferred_events1.occurrence_timestamp = quota_closed_and_transferred_events2.occurrence_timestamp))
        AND quota_closed_and_transferred_events1.operation::text <> 'D'::text;
    }
  end


  down do
    run "DROP VIEW public.quota_closed_and_transferred_events;"
  end
end
