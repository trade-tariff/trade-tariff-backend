Sequel.migration do
  up do
    # Add uuid column only if it doesn't exist
    unless self[:user_subscriptions].columns.include?(:uuid)
      alter_table(:user_subscriptions) do
        add_column :uuid, 'uuid', default: Sequel.lit('gen_random_uuid()'), null: false
      end
    end

    # Remove old primary key and column if present
    if self[:user_subscriptions].columns.include?(:id)
      # Drop the primary key constraint first
      execute "ALTER TABLE user_subscriptions DROP CONSTRAINT IF EXISTS user_subscriptions_pkey;"
      alter_table(:user_subscriptions) do
        drop_column :id
      end
    end

    # Set uuid as primary key
    unless primary_key(:user_subscriptions) == 'uuid'
      execute "ALTER TABLE user_subscriptions ADD PRIMARY KEY (uuid);"
    end
  end

  down do
    # Add id column back as primary key if needed
    unless self[:user_subscriptions].columns.include?(:id)
      # Drop the primary key constraint first
      execute "ALTER TABLE user_subscriptions DROP CONSTRAINT IF EXISTS user_subscriptions_pkey;"
      alter_table(:user_subscriptions) do
        add_primary_key :id
      end
    end

    # Drop uuid column if it exists
    if self[:user_subscriptions].columns.include?(:uuid)
      alter_table(:user_subscriptions) do
        drop_column :uuid
      end
    end
  end
end
