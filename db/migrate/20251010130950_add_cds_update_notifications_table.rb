Sequel.migration do
  up do
    create_table :cds_update_notifications do
      primary_key :id
      String :filename
      Integer :user_id
      DateTime :enqueued_at
    end
  end

  down do
    drop_table :cds_update_notifications
  end
end
