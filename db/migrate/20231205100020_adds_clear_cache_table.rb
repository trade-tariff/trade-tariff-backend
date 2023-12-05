Sequel.migration do
  up do
    create_table :clear_caches do
      primary_key :id
      Integer :user_id
      DateTime :enqueued_at
    end
  end

  down do
    drop_table :clear_caches
  end
end
