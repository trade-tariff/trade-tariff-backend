Sequel.migration do
  up do
    create_table :downloads do
      primary_key :id
      Integer :user_id
      DateTime :enqueued_at
    end

    create_table :applies do
      primary_key :id
      Integer :user_id
      DateTime :enqueued_at
    end
  end

  down do
    drop_table :downloads
    drop_table :applies
  end
end
