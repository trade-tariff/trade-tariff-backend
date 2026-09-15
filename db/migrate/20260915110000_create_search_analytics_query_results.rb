# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength, Rails/CreateTableWithTimestamps
Sequel.migration do
  up do
    alter_table(:search_analytics_collections) do
      add_column :query_results, :jsonb, null: false, default: Sequel.pg_jsonb({})
      add_index %i[service source reporting_date], unique: true,
                                                   where: Sequel.lit("status = 'running'"), name: :idx_search_analytics_running_window
      add_index %i[id service source reporting_date region log_group_name], unique: true, name: :idx_search_analytics_result_provenance
    end

    create_table :search_analytics_query_results do
      primary_key :id
      Integer :collection_id, null: false
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
      foreign_key %i[collection_id service source reporting_date region log_group_name], :search_analytics_collections,
                  key: %i[id service source reporting_date region log_group_name], name: :fk_search_analytics_result_provenance
      index %i[service source reporting_date name fingerprint], name: :idx_search_analytics_reusable_query
    end

    # Publications retain these IDs as evidence. Refreshes must insert new rows.
    run <<~SQL
      CREATE FUNCTION reject_search_analytics_result_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'Search analytics query results are immutable';
      END;
      $$;
      CREATE TRIGGER search_analytics_results_immutable
      BEFORE UPDATE OR DELETE ON search_analytics_query_results
      FOR EACH ROW EXECUTE FUNCTION reject_search_analytics_result_mutation();
    SQL
  end

  down do
    drop_table :search_analytics_query_results
    run 'DROP FUNCTION reject_search_analytics_result_mutation()'
    alter_table(:search_analytics_collections) do
      drop_index %i[id service source reporting_date region log_group_name], name: :idx_search_analytics_result_provenance
      drop_index %i[service source reporting_date], name: :idx_search_analytics_running_window
      drop_column :query_results
    end
  end
end
# rubocop:enable Metrics/BlockLength, Rails/CreateTableWithTimestamps
