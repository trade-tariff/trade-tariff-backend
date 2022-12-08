Sequel.migration do
  up do
    create_table :quota_closed_and_transferred_events_oplog do
      primary_key :oid # Oplog
      String :operation, size: 1, default: 'C' # Oplog
      Date :operation_date # Oplog

      Integer :quota_definition_sid, null: false
      DateTime :occurrence_timestamp, null: false
      Integer :target_quota_definition_sid, null: false
      Date :closing_date
      BigDecimal :transferred_amount, size: [15, 3]

      DateTime :created_at # Audit
      DateTime :updated_at # Audit
      String :filename # Audit

      index %i[quota_definition_sid occurrence_timestamp oid], name: :quota_closed_and_transferred_evt_pk
    end
  end

  down do
    drop_table :quota_closed_and_transferred_events_oplog
  end
end
