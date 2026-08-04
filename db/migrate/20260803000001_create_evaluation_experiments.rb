Sequel.migration do
  change do
    create_table(:evaluation_experiments) do
      primary_key :id
      column :name, String, null: false
      column :description, String
      column :enabled, TrueClass, null: false, default: true
      column :configuration_overrides, :jsonb, null: false, default: '{}'
      column :default_scope, :jsonb, null: false, default: '{}'
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_by, String

      index :name, unique: true
    end
  end
end
