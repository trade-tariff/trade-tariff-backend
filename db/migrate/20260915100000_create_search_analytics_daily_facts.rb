# frozen_string_literal: true

# Lifecycle timestamps (started, finished and published) are explicit rather than Rails timestamps.
# rubocop:disable Metrics/BlockLength, Rails/CreateTableWithTimestamps
Sequel.migration do
  change do
    create_table :search_analytics_collections do
      primary_key :id
      String :service, null: false
      String :source, null: false
      Date :reporting_date, null: false
      Integer :definition_version, null: false
      DateTime :window_start, null: false
      DateTime :window_end, null: false
      String :log_group_name, null: false
      String :region, null: false
      String :status, null: false
      BigDecimal :price_per_gb_usd, size: [20, 10], null: false
      DateTime :started_at, null: false
      DateTime :finished_at
      String :error_class
      index %i[id service source reporting_date definition_version], unique: true, name: :idx_search_analytics_collection_provenance
      index %i[service source reporting_date definition_version],
            unique: true, where: Sequel.lit("status = 'running'"), name: :idx_search_analytics_running_day
    end

    create_table :search_analytics_query_runs do
      primary_key :id
      foreign_key :collection_id, :search_analytics_collections, null: false
      String :name, null: false
      String :query_id
      String :status, null: false
      Bignum :bytes_scanned
      Bignum :records_scanned
      Bignum :records_matched
      Integer :result_rows
      Float :duration_seconds
      DateTime :started_at, null: false
      DateTime :finished_at
      String :error_class
      index %i[collection_id name], unique: true
    end

    create_table :search_analytics_days do
      primary_key :id
      String :service, null: false
      String :source, null: false
      Date :reporting_date, null: false
      Integer :definition_version, null: false
      Integer :collection_id, null: false
      DateTime :published_at, null: false
      Jsonb :facts, null: false
      foreign_key %i[collection_id service source reporting_date definition_version], :search_analytics_collections,
                  key: %i[id service source reporting_date definition_version], name: :fk_search_analytics_day_provenance
      index %i[service source reporting_date definition_version], unique: true, name: :idx_search_analytics_day_identity
    end
  end
end
# rubocop:enable Metrics/BlockLength, Rails/CreateTableWithTimestamps
