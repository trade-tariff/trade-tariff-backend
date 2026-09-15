# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:search_analytics_collections) do
      add_column :query_results, :jsonb, null: false, default: Sequel.pg_jsonb({})
      add_index %i[service source reporting_date], unique: true,
                                                   where: Sequel.lit("status = 'running'"), name: :idx_search_analytics_running_window
    end

    # Results are immutable; a forced collection creates another result, not an update.
    create_table :search_analytics_query_results do # rubocop:disable Rails/CreateTableWithTimestamps
      primary_key :id
      foreign_key :collection_id, :search_analytics_collections, null: false
      String :service, null: false
      String :source, null: false
      Date :reporting_date, null: false
      String :region, null: false
      String :log_group_name, null: false
      String :name, null: false
      String :fingerprint, null: false
      Jsonb :rows, null: false
      String :origin, null: false
      DateTime :created_at, null: false
      index %i[service source reporting_date name fingerprint], name: :idx_search_analytics_reusable_query
    end
  end
end
