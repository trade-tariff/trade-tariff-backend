Sequel.migration do
  up do
    unless self[:public__user_preferences].columns.include?(:created_at)
      alter_table(:user_preferences) do
        add_column :created_at, Time, null: true
      end
    end
  end

  down do
    if self[:public__user_preferences].columns.include?(:created_at)
      alter_table(:user_preferences) do
        drop_column :created_at
      end
    end
  end
end
