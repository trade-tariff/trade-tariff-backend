# frozen_string_literal: true

Sequel.migration do
  up do
    run <<-SQL
      DROP INDEX IF EXISTS quota_def_pk;
      CREATE INDEX quota_def_pk ON quota_definitions_oplog (quota_definition_sid, oid DESC);

      DROP INDEX IF EXISTS quota_balance_evt_pk;
      CREATE INDEX quota_balance_evt_pk ON quota_balance_events_oplog (quota_definition_sid, occurrence_timestamp, oid DESC)
    SQL
  end

  down do
    run <<-SQL
      DROP INDEX IF EXISTS quota_def_pk;
      CREATE INDEX quota_def_pk ON quota_definitions_oplog (quota_definition_sid);

      DROP INDEX IF EXISTS quota_balance_evt_pk;
      CREATE INDEX quota_balance_evt_pk ON quota_balance_events_oplog (quota_definition_sid, occurrence_timestamp)
    SQL
  end

end
