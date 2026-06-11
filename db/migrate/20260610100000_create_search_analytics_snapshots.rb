# frozen_string_literal: true

Sequel.migration do
  change do
    unless Sequel::Model.db.table_exists?(:search_analytics_snapshots)
      create_table :search_analytics_snapshots do
        primary_key :id
        String :service, null: false
        String :period, null: false
        String :view, null: false
        String :bucket_size, null: false
        DateTime :generated_at, null: false
        DateTime :data_through, null: false
        Jsonb :payload, null: false, default: Sequel.lit("'{}'::jsonb")
        DateTime :created_at
        DateTime :updated_at

        index :service
        index :period
        index :view
        index :generated_at
        index :data_through
        index %i[service period view generated_at],
              unique: true,
              name: :idx_search_analytics_snapshots_unique_window
      end
    end
  end
end
