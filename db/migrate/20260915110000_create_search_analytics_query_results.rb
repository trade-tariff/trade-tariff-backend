# frozen_string_literal: true

Sequel.migration do
  change do
    # A refreshed result replaces the same service/day/query slot.
    create_table :search_analytics_query_results do # rubocop:disable Rails/CreateTableWithTimestamps
      primary_key :id
      String :service, null: false
      Date :reporting_date, null: false
      String :name, null: false
      String :fingerprint, null: false
      Jsonb :rows, null: false
      DateTime :collected_at, null: false
      index %i[service reporting_date name], unique: true, name: :idx_search_analytics_daily_query
    end
  end
end
