Sequel.migration do
  up do
    # Remove duplicate records from quota_balance_events_oplog
    # based on the combination of quota_definition_sid and occurrence_timestamp.
    # Keep the record with the maximum oid for each combination.
    run <<~SQL
      WITH max_oids AS (
        SELECT quota_definition_sid, occurrence_timestamp, MAX(oid) AS max_oid
        FROM quota_balance_events_oplog
        GROUP BY quota_definition_sid, occurrence_timestamp
      )
      DELETE FROM quota_balance_events_oplog
      USING max_oids
      WHERE quota_balance_events_oplog.quota_definition_sid = max_oids.quota_definition_sid
        AND quota_balance_events_oplog.occurrence_timestamp = max_oids.occurrence_timestamp
        AND quota_balance_events_oplog.oid != max_oids.max_oid;
    SQL
  end

  down do
    # Not reversible
  end
end
